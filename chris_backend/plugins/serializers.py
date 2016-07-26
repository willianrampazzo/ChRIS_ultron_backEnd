
from rest_framework import serializers

from .models import Plugin, PluginParameter, PluginInstance, StringParameter
from .models import FloatParameter, IntParameter, BoolParameter


class PluginSerializer(serializers.HyperlinkedModelSerializer):
    parameters = serializers.HyperlinkedIdentityField(view_name='pluginparameter-list')
    instances = serializers.HyperlinkedIdentityField(view_name='plugininstance-list')
    
    class Meta:
        model = Plugin
        fields = ('url', 'id', 'name', 'type', 'parameters', 'instances')


class PluginParameterSerializer(serializers.HyperlinkedModelSerializer):
    plugin = serializers.HyperlinkedRelatedField(view_name='plugin-detail',
                                                 read_only=True)    
    class Meta:
        model = PluginParameter
        fields = ('url', 'name', 'type', 'optional', 'plugin')


class PluginInstanceSerializer(serializers.HyperlinkedModelSerializer):
    plugin_name = serializers.ReadOnlyField(source='plugin.name')
    owner = serializers.ReadOnlyField(source='owner.username')
    plugin = serializers.HyperlinkedRelatedField(view_name='plugin-detail',
                                                 read_only=True)
    feed = serializers.HyperlinkedRelatedField(view_name='feed-detail',
                                               read_only=True)
    string_param = serializers.HyperlinkedRelatedField(many=True,
                                                       view_name='stringparameter-detail',
                                                       read_only=True)
    int_param = serializers.HyperlinkedRelatedField(many=True,
                                                    view_name='intparameter-detail',
                                                    read_only=True)
    float_param = serializers.HyperlinkedRelatedField(many=True,
                                                    view_name='floatparameter-detail',
                                                    read_only=True)
    bool_param = serializers.HyperlinkedRelatedField(many=True,
                                                    view_name='boolparameter-detail',
                                                    read_only=True)
    
    class Meta:
        model = PluginInstance
        fields = ('url', 'plugin_name', 'owner', 'feed', 'plugin', 'string_param',
                  'int_param', 'float_param', 'bool_param')


class StringParameterSerializer(serializers.HyperlinkedModelSerializer):
    param_name = serializers.ReadOnlyField(source='plugin_param.name')
    plugin_inst = serializers.HyperlinkedRelatedField(view_name='plugininstance-detail',
                                                 read_only=True)
    plugin_param = serializers.HyperlinkedRelatedField(view_name='pluginparameter-detail',
                                                 read_only=True)   
    class Meta:
        model = StringParameter
        fields = ('url', 'param_name', 'value', 'plugin_inst', 'plugin_param')


class IntParameterSerializer(serializers.HyperlinkedModelSerializer):
    param_name = serializers.ReadOnlyField(source='plugin_param.name')
    plugin_inst = serializers.HyperlinkedRelatedField(view_name='plugininstance-detail',
                                                 read_only=True)
    plugin_param = serializers.HyperlinkedRelatedField(view_name='pluginparameter-detail',
                                                 read_only=True)
    
    class Meta:
        model = IntParameter
        fields = ('url', 'param_name', 'value', 'plugin_inst', 'plugin_param')


class FloatParameterSerializer(serializers.HyperlinkedModelSerializer):
    param_name = serializers.ReadOnlyField(source='plugin_param.name')
    plugin_inst = serializers.HyperlinkedRelatedField(view_name='plugininstance-detail',
                                                 read_only=True)
    plugin_param = serializers.HyperlinkedRelatedField(view_name='pluginparameter-detail',
                                                 read_only=True)
    
    class Meta:
        model = FloatParameter
        fields = ('url', 'param_name', 'value', 'plugin_inst', 'plugin_param')


class BoolParameterSerializer(serializers.HyperlinkedModelSerializer):
    param_name = serializers.ReadOnlyField(source='plugin_param.name')
    plugin_inst = serializers.HyperlinkedRelatedField(view_name='plugininstance-detail',
                                                 read_only=True)
    plugin_param = serializers.HyperlinkedRelatedField(view_name='pluginparameter-detail',
                                                 read_only=True)
    
    class Meta:
        model = BoolParameter
        fields = ('url', 'param_name', 'value', 'plugin_inst', 'plugin_param')
        

PARAMETER_SERIALIZERS={'string': StringParameterSerializer,
                       'integer': IntParameterSerializer,
                       'float': FloatParameterSerializer,
                       'boolean': BoolParameterSerializer}
