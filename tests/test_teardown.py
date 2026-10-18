"""Offline teardown tests; no AWS credentials or cluster required."""
import ast
import logging
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock

import yaml

ROOT = Path(__file__).resolve().parents[1]


class TemplateLoader(yaml.SafeLoader):
    pass


def intrinsic(loader, tag, node):
    if isinstance(node, yaml.ScalarNode):
        value = loader.construct_scalar(node)
    elif isinstance(node, yaml.SequenceNode):
        value = loader.construct_sequence(node)
    else:
        value = loader.construct_mapping(node)
    return {tag: value}


TemplateLoader.add_multi_constructor('!', intrinsic)


class ClientError(Exception):
    def __init__(self, code):
        self.response = {'Error': {'Code': code}}
        super().__init__(code)


def functions(source, names, namespace):
    tree = ast.parse(source)
    selected = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in names]
    for node in selected:
        node.decorator_list = []
    exec(compile(ast.Module(body=selected, type_ignores=[]), '<teardown>', 'exec'), namespace)
    return namespace


class HelmDeletionTest(unittest.TestCase):
    def setUp(self):
        self.eks = Mock()
        self.helm = Mock()
        self.ns = functions((ROOT / 'functions/source/WebStack/lambda_function.py').read_text(),
                            {'helm_uninstall', 'cluster_is_missing', 'cluster_api_unreachable'},
                            {'eks_client': self.eks, 'ClientError': ClientError, 'logger': logging.getLogger(__name__),
                             'run_helm': self.helm, 'helm_kube_args': Mock(return_value=[])})
        self.props = {'Name': 'dashboard', 'Namespace': 'dashboard', 'ClusterName': 'test-cluster'}

    def test_live_cluster_network_failure_does_not_detach_release(self):
        self.helm.side_effect = RuntimeError('Kubernetes cluster unreachable: i/o timeout')
        with self.assertRaises(RuntimeError):
            self.ns['helm_uninstall'](self.props)
        self.eks.describe_cluster.assert_called_once_with(name='test-cluster')

    def test_missing_cluster_is_safe_to_retry(self):
        self.ns['helm_kube_args'].side_effect = ClientError('ResourceNotFoundException')
        self.eks.describe_cluster.side_effect = ClientError('ResourceNotFoundException')
        self.ns['helm_uninstall'](self.props)
        self.helm.assert_not_called()

    def test_missing_release_does_not_require_cluster_probe(self):
        self.helm.side_effect = RuntimeError('uninstall: Release not loaded: dashboard: release: not found')
        self.ns['helm_uninstall'](self.props)
        self.eks.describe_cluster.assert_not_called()

    def test_permission_failure_is_not_mistaken_for_missing_cluster(self):
        self.helm.side_effect = RuntimeError('Kubernetes cluster unreachable')
        self.eks.describe_cluster.side_effect = ClientError('AccessDeniedException')
        with self.assertRaises(ClientError):
            self.ns['helm_uninstall'](self.props)


class LoadBalancerDeletionTest(unittest.TestCase):
    def setUp(self):
        self.template = yaml.load((ROOT / 'eks.yaml').read_text(), Loader=TemplateLoader)
        source = self.template['Resources']['CleanupLoadBalancersFunction']['Properties']['Code']['ZipFile']
        self.api, self.send = Mock(), Mock()
        self.context = Mock()
        self.context.get_remaining_time_in_millis.return_value = 100000
        self.ns = functions(source, {'owned', 'missing', 'handler'},
                            {'boto3': SimpleNamespace(client=Mock(return_value=self.api)), 'Config': Mock(),
                             'ClientError': ClientError, 'send': self.send, 'time': SimpleNamespace(sleep=Mock())})
        self.event = {'RequestType': 'Delete', 'ResourceProperties': {'ClusterName': 'test-cluster'}}

    def inventory(self):
        lbs = Mock()
        lbs.paginate.return_value = [{'LoadBalancers': [{'LoadBalancerArn': 'owned-lb'}, {'LoadBalancerArn': 'other-lb'}]}]
        targets = Mock()
        targets.paginate.return_value = [{'TargetGroups': [{'TargetGroupArn': 'owned-tg'}, {'TargetGroupArn': 'other-tg'}]}]
        self.api.get_paginator.side_effect = lambda name: lbs if name == 'describe_load_balancers' else targets
        self.api.describe_tags.side_effect = lambda ResourceArns: {'TagDescriptions': [{'Tags': [
            {'Key': 'elbv2.k8s.aws/cluster', 'Value': 'test-cluster' if ResourceArns[0].startswith('owned') else 'another-cluster'}]}]}

    def test_waits_for_owned_load_balancers_before_deleting_owned_targets(self):
        self.inventory()
        self.api.describe_load_balancers.side_effect = [{}, ClientError('LoadBalancerNotFound')]
        self.ns['handler'](self.event, self.context)
        self.api.delete_load_balancer.assert_called_once_with(LoadBalancerArn='owned-lb')
        self.api.delete_target_group.assert_called_once_with(TargetGroupArn='owned-tg')
        calls = self.api.method_calls
        self.assertLess(max(i for i, c in enumerate(calls) if c[0] == 'describe_load_balancers'),
                        next(i for i, c in enumerate(calls) if c[0] == 'delete_target_group'))
        self.send.assert_called_once_with(self.event, self.context, 'SUCCESS')

    def test_deadline_returns_failure_instead_of_silent_success(self):
        self.inventory()
        self.context.get_remaining_time_in_millis.return_value = 40000
        self.ns['handler'](self.event, self.context)
        self.assertEqual('FAILED', self.send.call_args.args[2])
        self.api.delete_target_group.assert_not_called()

    def test_delete_permission_errors_are_reported(self):
        self.inventory()
        self.api.delete_load_balancer.side_effect = ClientError('AccessDenied')
        self.ns['handler'](self.event, self.context)
        self.assertEqual('FAILED', self.send.call_args.args[2])
        self.api.delete_target_group.assert_not_called()

    def test_creation_does_not_delete_anything(self):
        self.event['RequestType'] = 'Create'
        self.ns['handler'](self.event, self.context)
        self.api.get_paginator.assert_not_called()
        self.send.assert_called_once_with(self.event, self.context, 'SUCCESS')

    def test_dependency_graph_keeps_nodes_until_chart_and_fallback_cleanup(self):
        resources = self.template['Resources']
        self.assertIn('CleanupLoadBalancers', resources['WebStack']['DependsOn'])
        self.assertEqual({'If': ['CreateNodeGroup', {'Ref': 'NodeGroup'}, 'disabled']},
                         resources['CleanupLoadBalancers']['Properties']['NodeGroupDependency'])
        self.assertEqual(900, resources['CleanupLoadBalancers']['Properties']['ServiceTimeout'])


class ClusterAccessTest(unittest.TestCase):
    def test_helm_installer_access_uses_stack_managed_role(self):
        resources = yaml.load((ROOT / 'eks.yaml').read_text(), Loader=TemplateLoader)['Resources']
        installer_role = resources['WebStackLambda']['Properties']['Role']
        granted_roles = [resource['Properties']['PrincipalArn'] for resource in resources.values()
                         if resource['Type'] == 'AWS::EKS::AccessEntry']
        self.assertIn(installer_role, granted_roles)
        self.assertNotIn('HelmAccessEntry', resources)
        self.assertNotIn('awsqs-kubernetes-helm', (ROOT / 'eks.yaml').read_text())


if __name__ == '__main__':
    unittest.main()
