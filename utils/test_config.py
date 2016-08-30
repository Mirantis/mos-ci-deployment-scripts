
import pytest

from config import Config


def test_config_structure():
    config = Config(env_name='test_env_name', release='ubuntu')
    result = config.to_dict()
    assert 'template' in result
    template = result['template']

    assert 'name' in template
    assert template['name'] == 'test_env_name'

    assert 'slaves' in template

    assert isinstance(template['slaves'], int)
    assert 'cluster_template' in template

    assert isinstance(template['cluster_template'], dict)
    assert template['cluster_template']['name'] == 'test_env_name'
    assert template['cluster_template']['release'] == 'ubuntu'
    assert 'devops_settings' in template

    assert isinstance(template['devops_settings'], dict)

# def test_add_node(config):
