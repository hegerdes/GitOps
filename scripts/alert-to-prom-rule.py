#!/usr/bin/env python3

import re
import os
import yaml
import requests
from typing import List, Dict, Any

OUT_DIR = os.path.join(os.path.dirname(__file__), 'rules')
PROMETHEUS_RULE_TEMPLATE = {
    'apiVersion': 'monitoring.coreos.com/v1',
    'kind': 'PrometheusRule',
    'metadata': {'name': '', 'labels': {}, 'annotations': {}},
    'spec': '',
}


def sanitize_name(name: str, max_len: int = 63) -> str:
    s = name.lower()
    # replace invalid chars with '-'
    s = re.sub(r'[^a-z0-9\-]+', '-', s)
    # collapse multiple '-'
    s = re.sub(r'-{2,}', '-', s)
    # strip leading/trailing '-'
    s = s.strip('-')
    if len(s) > max_len:
        s = s[:max_len].rstrip('-')
    return s


def load_yaml_documents(paths: List[str]) -> Dict[str, Dict[str, Any]]:
    docs = {}
    for path in paths:
        with os.open(path, 'r') as f:
            for doc in yaml.safe_load_all(f):
                if doc is None:
                    continue
                docs[sanitize_name(path)] = list(doc)[0]
    return docs


def get_rules_from_urls(urls: Dict[str, str]) -> Dict[str, Dict[str, Any]]:
    docs = {}
    for name, url in urls.items():
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        docs[name] = list(yaml.safe_load_all(response.text))[0]
    return docs


def convert_rules(docs: Dict[str, List[Dict[str, Any]]], out_dir: str = OUT_DIR):
    for k, v in docs.items():
        rendered = dict(PROMETHEUS_RULE_TEMPLATE)
        rendered['metadata']['name'] = sanitize_name(k)
        rendered['spec'] = v
        print('Writing rules for', k)
        out_file = os.path.join(out_dir, f"prometheus-rule-{sanitize_name(k)}.yaml")
        with open(out_file, 'w') as f:
            yaml.dump(
                rendered,
                f,
                default_flow_style=False,
                allow_unicode=True,
                indent=2,
            )


if __name__ == '__main__':
    os.makedirs(OUT_DIR, exist_ok=True)

    # https://samber.github.io/awesome-prometheus-alerts/rules.html
    urls = {
        'node-exporter': 'https://gist.github.com/krisek/62a98e2645af5dce169a7b506e999cd8/raw/b67dd1dad1bcf2896f56dd02a657d8eac8e893ea/alert.rules.yml',
        'kubernetes': 'https://raw.githubusercontent.com/samber/awesome-prometheus-alerts/master/dist/rules/kubernetes/kubestate-exporter.yml',
        'argocd': 'https://raw.githubusercontent.com/samber/awesome-prometheus-alerts/master/dist/rules/argocd/embedded-exporter.yml',
        'coredns': 'https://raw.githubusercontent.com/samber/awesome-prometheus-alerts/master/dist/rules/coredns/embedded-exporter.yml',
    }

    docs = get_rules_from_urls(urls)
    convert_rules(docs)
