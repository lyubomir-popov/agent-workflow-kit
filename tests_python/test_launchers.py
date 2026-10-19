"""Native worker launcher resolution without executing shell wrappers."""

import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from wfk import launchers, processes


PACKAGES = {
    'codex': ('@openai/codex', 'bin/codex.js'),
    'copilot': ('@github/copilot', 'npm-loader.js'),
    'claude': ('@anthropic-ai/claude-code', 'cli.js'),
}


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='wfk npm launchers spaces ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'npm bin ☃'
        self.bin.mkdir()

    def write_file(self, path, content='fixture'):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8')
        return path

    def npm_install(self, command, *, entry=True, metadata_entry=None, local_node=True,
                    suffix='.cmd'):
        package_name, expected_entry = PACKAGES[command]
        shim = self.write_file(
            self.bin / f'{command}{suffix}',
            '@ECHO off\r\ntitle %COMSPEC% & "malicious fake" %*\r\n',
        )
        package = self.bin / 'node_modules'
        for part in package_name.split('/'):
            package /= part
        declared = expected_entry if metadata_entry is None else metadata_entry
        self.write_file(package / 'package.json', json.dumps({
            'name': package_name,
            'bin': {command: declared},
        }))
        entry_path = package / expected_entry
        if entry:
            self.write_file(entry_path, '// fixture entry; resolution must not execute this\n')
        node = self.bin / 'node.exe'
        if local_node:
            self.write_file(node)
        return shim, node, entry_path

    def env(self, *directories):
        return patch.dict(os.environ, {
            'PATH': os.pathsep.join(str(path) for path in directories),
            'PATHEXT': '.COM;.EXE;.BAT;.CMD;.PS1',
        })

    def test_posix_preserves_vector_and_validates_absolute_executable(self):
        executable = self.write_file(self.root / 'native tool')
        executable.chmod(0o755)
        arguments = [str(executable), 'space & | ^ $(literal)', '雪']
        self.assertEqual(launchers.resolve(arguments, platform='posix'), arguments)
        with self.assertRaisesRegex(ValueError, 'executable unavailable'):
            launchers.resolve([str(self.root / 'missing')], platform='posix')
        if os.name != 'nt':
            executable.chmod(0o644)
            with self.assertRaisesRegex(ValueError, 'executable unavailable'):
                launchers.resolve(arguments, platform='posix')

    def test_posix_bare_executable_must_resolve_but_vector_is_unchanged(self):
        command = 'wfk-launcher-bare-fixture'
        executable = self.write_file(self.bin / command, '#!/bin/sh\n')
        executable.chmod(0o755)
        arguments = [command, 'literal & | 雪']
        with patch('wfk.launchers.shutil.which', return_value=str(executable)):
            self.assertEqual(launchers.resolve(arguments, platform='posix'), arguments)
        with patch('wfk.launchers.shutil.which', return_value=None), \
                self.assertRaisesRegex(ValueError, 'executable unavailable'):
            launchers.resolve(arguments, platform='posix')

    def test_windows_native_executable_is_absolute_and_arguments_stay_atomic(self):
        native = self.write_file(self.bin / 'worker.exe')
        prompt = 'space & | ^ $(literal) " 雪'
        with self.env(self.bin):
            resolved = launchers.resolve(['worker', '--prompt', prompt], platform='nt')
        self.assertEqual(resolved, [str(native.resolve()), '--prompt', prompt])

    def test_windows_known_npm_shims_use_local_node_and_validated_entries(self):
        prompt = 'one argument & | ^ %COMSPEC% $(never) " ☃'
        path_node_bin = self.root / 'earlier node on PATH'
        self.write_file(path_node_bin / 'node.exe')
        for command in PACKAGES:
            with self.subTest(command=command):
                _, node, entry = self.npm_install(command)
                with self.env(path_node_bin, self.bin):
                    resolved = launchers.resolve([command, prompt], cwd=self.root,
                                                 platform='nt')
                self.assertEqual(resolved, [str(node.resolve()), str(entry.resolve()), prompt])

    def test_windows_npm_node_falls_back_only_to_native_node_exe_on_path(self):
        _, _, entry = self.npm_install('copilot', local_node=False)
        node_bin = self.root / 'node path'
        node = self.write_file(node_bin / 'node.exe')
        self.write_file(self.bin / 'node.cmd', '@echo unsafe')
        self.write_file(self.bin / 'node.ps1', 'Write-Output unsafe')
        with self.env(self.bin, node_bin):
            self.assertEqual(
                launchers.resolve(['copilot', 'arg'], platform='nt'),
                [str(node.resolve()), str(entry.resolve()), 'arg'],
            )

        node.unlink()
        with self.env(self.bin, node_bin), self.assertRaisesRegex(ValueError, 'native Node'):
            launchers.resolve(['copilot'], platform='nt')

    def test_windows_explicit_npm_shim_path_ignores_arbitrary_shim_text(self):
        shim, node, entry = self.npm_install('codex')
        argument = 'literal && echo compromised | more'
        with self.env(self.bin):
            resolved = launchers.resolve([str(shim), argument], platform='nt')
        self.assertEqual(resolved, [str(node.resolve()), str(entry.resolve()), argument])
        self.assertNotIn('cmd.exe', ' '.join(resolved).lower())
        self.assertNotIn('comspec', ' '.join(resolved).lower())

    def test_windows_ps1_and_bat_only_npm_shims_use_metadata_without_shells(self):
        for command, suffix in (('copilot', '.ps1'), ('claude', '.bat')):
            with self.subTest(command=command, suffix=suffix):
                shim, node, entry = self.npm_install(command, suffix=suffix)
                with self.env(self.bin):
                    resolved = launchers.resolve([str(shim), '& | ^ ☃'], platform='nt')
                self.assertEqual(resolved,
                                 [str(node.resolve()), str(entry.resolve()), '& | ^ ☃'])

    @unittest.skipUnless(os.name == 'nt' and shutil.which('node'),
                         'native Windows Node execution fixture')
    def test_resolved_node_process_receives_metacharacters_as_one_argument(self):
        shim, _, entry = self.npm_install('copilot', local_node=False)
        entry.write_text(
            "const fs = require('fs');\n"
            "fs.writeFileSync(process.argv[2], JSON.stringify(process.argv.slice(3)), 'utf8');\n",
            encoding='utf-8',
        )
        report = self.root / 'node argv.json'
        marker = self.root / 'shell side effect'
        prompt = f'& echo compromised > "{marker}" | ^ %COMSPEC% $(never) ☃'
        node_directory = Path(shutil.which('node')).parent
        with self.env(self.bin, node_directory):
            resolved = launchers.resolve([str(shim), str(report), prompt], platform='nt')
            result = processes.execute(resolved, self.root, self.root / 'node.log', timeout=10)
        self.assertEqual(result['returncode'], 0)
        self.assertEqual(json.loads(report.read_text(encoding='utf-8')), [prompt])
        self.assertFalse(marker.exists())

    def test_windows_npm_metadata_or_entry_mismatch_fails_closed(self):
        cases = (
            ('missing entry', dict(entry=False), 'entrypoint'),
            ('unexpected metadata entry', dict(metadata_entry='other.js'), 'metadata'),
            ('traversal metadata entry', dict(metadata_entry='../../outside.js'), 'metadata'),
        )
        for label, options, message in cases:
            with self.subTest(label=label):
                command = 'copilot'
                shim, _, _ = self.npm_install(command, **options)
                with self.env(self.bin), self.assertRaisesRegex(ValueError, message):
                    launchers.resolve([str(shim)], platform='nt')
                for child in sorted(self.bin.iterdir(), reverse=True):
                    if child.is_file():
                        child.unlink()

    def test_windows_unknown_or_unbacked_shell_wrappers_fail_closed(self):
        for suffix in ('.cmd', '.bat', '.ps1'):
            self.write_file(self.bin / f'unknown{suffix}', 'arbitrary shell text')
        with self.env(self.bin), self.assertRaisesRegex(ValueError, 'native|wrapper'):
            launchers.resolve(['unknown'], platform='nt')
        self.write_file(self.bin / 'copilot.cmd', '@echo package is absent')
        with self.env(self.bin), self.assertRaisesRegex(ValueError, 'native|wrapper'):
            launchers.resolve(['copilot'], platform='nt')

    def test_invalid_argument_vectors_fail_before_resolution(self):
        for argv in ([], 'worker arg', [42], ['worker', 'bad\0arg']):
            with self.subTest(argv=argv), self.assertRaises(ValueError):
                launchers.resolve(argv)
        with self.assertRaisesRegex(ValueError, 'platform'):
            launchers.resolve(['worker'], platform='other')


if __name__ == '__main__':
    unittest.main()
