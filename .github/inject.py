import os, sys

required = ['ADMIN_PWD', 'WA_NUMBER', 'NUM_MESAS']
secrets = {}

for key in required:
    val = os.environ.get(key, '')
    if not val:
        print(f'ERROR: secret {key} is not set or is empty', file=sys.stderr)
        sys.exit(1)
    secrets[key] = val

replacements = {
    'dist/index.html': [
        ('__ADMIN_PWD__', secrets['ADMIN_PWD']),
    ],
    'dist/litzy.html': [
        ('__WA_NUMBER__', secrets['WA_NUMBER']),
        ('__NUM_MESAS__', secrets['NUM_MESAS']),
    ],
}

for path, pairs in replacements.items():
    with open(path, encoding='utf-8') as f:
        content = f.read()
    for placeholder, value in pairs:
        if placeholder not in content:
            print(f'WARNING: {placeholder} not found in {path}', file=sys.stderr)
        content = content.replace(placeholder, value)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'OK: {path}')

print('All secrets injected.')
