#############################
##                         ##
##    BARNYARD-CONF SLS    ##
##                         ##
#############################

################################################################################
#!!!!!!!!!!                                                        !!!!!!!!!!!!!
#          See /opt/onionsalt/pillar/barnyard-conf.sls for details,
#                all configuration happens in that pillar.
#                    No need to change anything here.
#!!!!!!!!!!                                                        !!!!!!!!!!!!!
################################################################################

{% if pillar['barnyard-conf']['enabled'] %}

# Variables we are using - get them into some easier/shorter names.
{% set syslog_server   = pillar['barnyard-conf']['syslog_server'] %}
{% set syslog_port     = pillar['barnyard-conf']['syslog_port'] %}
{% set syslog_protocol = pillar['barnyard-conf']['syslog_protocol'] %}
{% set nodename        = grains['nodename'] %}

# SOSETUP defaults to half_cpus, we check if a grain has been defined and if it
# has use that, if no, just set the lb_procs to have the CPUs. The number of
# barnyard processes on each sensor equals lb_procs.
{% set half_cpus = (grains['num_cpus']/2)|round|int %}
{% if grains['ids_lb_procs'] is defined %}
{% set lb_procs = grains['ids_lb_procs'] %}
{% else %}
{% set lb_procs = half_cpus %}
{% endif %}

# Check if the sensor_interface grain is defined, otherwise just assume we are
# only listening on eth1.
{% if grains['sensor_interfaces'] is defined %}
{% set sensor_interfaces = grains['sensor_interfaces'] %}
{% else %}
{% set sensor_interfaces = ['eth1'] %}
{% endif %}

{% for interface in sensor_interfaces %}
{% set sensorname = '{0}-{1}'.format(nodename, interface) %}

{{ sensorname }}-barnyard2-conf:
  file.blockreplace:
    - name: /etc/nsm/{{ sensorname }}/barnyard2.conf
    - marker_start: "# Begin Onionsalt awesomeness"
    - marker_end: "# Done Onionsalt awesomeness."
    - append_if_not_found: True
    - content: |
        output alert_syslog_full: sensor_name {{ sensorname }}, server {{ syslog_server }}, protocol udp, port 514, operation_mode default

{% for ids_worker in range(1, (1+lb_procs)) %}
barnyard-{{ sensorname }}-{{ ids_worker }}-conf:
  file.blockreplace:
    - name: /etc/nsm/{{ sensorname }}/barnyard2-{{ ids_worker }}.conf
    - marker_start: "# Begin Onionsalt awesomeness"
    - marker_end: "# Done Onionsalt awesomeness."
    - append_if_not_found: True
    - content: |
        output alert_syslog_full: sensor_name {{ sensorname }}, server {{ syslog_server }}, protocol {{ syslog_protocol }}, port {{ syslog_port }}, operation_mode default

{% endfor %}
{% endfor %}

restart-barnyard-and-workers:
  cmd.wait:
    - name: /usr/sbin/nsm_sensor_ps-restart --only-barnyard2
    - cwd: /
    - watch:
{% for interface in sensor_interfaces %}
{% set sensorname = '{0}-{1}'.format(nodename, interface) %}
      - file: /etc/nsm/{{ sensorname }}/barnyard2.conf
{% for ids_worker in range(1, (1+lb_procs)) %}
      - file: /etc/nsm/{{ sensorname }}/barnyard2-{{ ids_worker }}.conf
{% endfor %}
{% endfor %}

{% endif %}
