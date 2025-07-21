import os
import yaml
from collections import Counter

ROOT = os.path.dirname(os.path.abspath(__file__))


def load_yaml(path):
    try:
        with open(path) as f:
            return yaml.safe_load(f) or {}
    except FileNotFoundError:
        return {}


def main():
    lint = load_yaml(os.path.join(ROOT, 'lint_status.yaml'))
    audit = load_yaml(os.path.join(ROOT, 'audit_output.yaml'))

    score = audit.get('score', 0)
    total = lint.get('total', 0)
    violations = Counter(lint.get('violations', {}))
    top_offenders = violations.most_common(5)

    lines = [
        '# Progress Tracker',
        f'## Validation Score: {score}/100',
        f'## ansible-lint Violations: {total}',
        '',
        '### Top Violations'
    ]
    for rule, count in top_offenders:
        lines.append(f'- {rule}: {count}')

    lines.append('')
    lines.append('### Next Steps')
    if total:
        lines.append('- Fix lint rules starting with the highest counts.')
    if score < 100:
        lines.append('- Resolve validation issues reported in validation_report.md')
    else:
        lines.append('- Maintain validation score while reducing lint errors.')

    with open(os.path.join(ROOT, 'progress.md'), 'w') as fh:
        fh.write('\n'.join(lines) + '\n')

    print('progress.md updated')


if __name__ == '__main__':
    main()
