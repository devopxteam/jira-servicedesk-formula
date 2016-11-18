{%- from 'jira-servicedesk/conf/settings.sls' import jira with context %}

include:
  - sun-java
  - sun-java.env
  - mysql
  - mysql.remove_test_database
  - nginx.ng

jira: 
  group:
    - present
  user.present:
    - fullname: Jira user
    - shell: /bin/sh
    - home: {{ jira.home }} 
    - groups:
       - jira
  
### APPLICATION INSTALL ###
unpack-jira-tarball:
  archive.extracted:
    - name: {{ jira.prefix }}
    - source: {{ jira.source_url }}/{{ jira.app_name }}-{{ jira.version }}.tar.gz
    - archive_format: tar
    - skip_verify: true
    - user: jira 
    - tar_options: z
    {% if jira.app_name == 'atlassian-servicedesk' %}
    - if_missing: {{ jira.prefix }}/atlassian-jira-servicedesk-{{ jira.version }}-standalone
    {% elif jira.app_name == 'jira' %}
    - if_missing: {{ jira.prefix }}/atlassian-jira-{{ jira.version }}-standalone
    {% endif %}
    
    - keep: True
    - require:
      - module: jira-stop
      - file: jira-init-script
    - listen_in:
      - module: jira-restart

create-jira-symlink:
  file.symlink:
    - name: {{ jira.prefix }}/jira
    {% if jira.app_name == 'atlassian-servicedesk' %}
    - target: {{ jira.prefix }}/atlassian-jira-servicedesk-{{ jira.version }}-standalone
    {% elif jira.app_name == 'jira' %}
    - target: {{ jira.prefix }}/atlassian-jira-{{ jira.version }}-standalone
    {% endif %}
    - user: jira
    - watch:
      - archive: unpack-jira-tarball

create-logs-symlink:
  file.symlink:
    - name: {{ jira.prefix }}/jira/logs
    - target: {{ jira.log_root }}
    - user: jira
    - backupname: {{ jira.prefix }}/jira/old_logs
    - watch:
      - archive: unpack-jira-tarball

unpack-mysql-tarball:
  archive.extracted:
    - name: /tmp/
    - source: {{ jira.mysql_location }}/mysql-connector-java-{{ jira.mysql_connector_version }}.tar.gz
    - skip_verify: true
    - archive_format: tar
    - user: jira 
    - tar_options: z
    - if_missing: {{ jira.prefix }}/jira/lib/mysql-connector-java-{{ jira.mysql_connector_version }}-bin.jar
    - keep: True

{% if not salt['file.directory_exists' ]('{{ jira.prefix }}/jira/lib/mysql-connector-java-{{ jira.mysql_connector_version }}-bin.jar') %}
mysql-jar-copy:
  file.copy:
    - name: {{ jira.prefix }}/jira/lib/mysql-connector-java-{{ jira.mysql_connector_version }}-bin.jar
    - source: /tmp/mysql-connector-java-5.1.40/mysql-connector-java-{{ jira.mysql_connector_version }}-bin.jar
    - user: jira
    - require:
      - module: jira-stop
      - file: jira-init-script
    - listen_in:
      - module: jira-restart   
{% endif %}


fix-jira-filesystem-permissions:
  file.directory:
    - user: jira
    - group: jira
    - recurse:
      - user
      - group
    - names:
    {% if jira.app_name == 'atlassian-servicedesk' %}
      - {{ jira.prefix }}/atlassian-jira-servicedesk-{{ jira.version }}-standalone
    {% elif jira.app_name == 'jira' %}
      - {{ jira.prefix }}/atlassian-jira-{{ jira.version }}-standalone
    {% endif %}
      - {{ jira.home }}
      - {{ jira.log_root }}
    - watch:
      - archive: unpack-jira-tarball

#jira-init-script:
#  file.managed:
#    - name: '/etc/init.d/jira'
#    - source: salt://jira-servicedesk/templates/jira.init.tmpl
#    - user: root
#    - group: root
#    - mode: 0755
#    - template: jinja
#    - context:
#      jira: {{ jira|json }}


/usr/lib/systemd/system:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

jira-init-script:
  file.managed:
    - name: '/usr/lib/systemd/system/jira.service'
    - source: salt://jira-servicedesk/templates/jira.systemd.tmpl
    - user: root
    - group: root
    - mode: 0755
    - template: jinja
    - context:
      jira: {{ jira|json }}

systemctl daemon-reload:
  cmd.run

jira-properties-file:
  file.managed:
    - name: '{{ jira.prefix }}/jira/atlassian-jira/WEB-INF/classes/jira-application.properties'
    - source: salt://jira-servicedesk/templates/jira-application.properties.tmpl
    - user: jira
    - group: jira
    - mode: 0755
    - template: jinja
    - context:
      jira: {{ jira|json }}

{{ jira.home }}/dbconfig.xml:
  file.managed:
    - source: salt://jira-servicedesk/templates/dbconfig.xml.tmpl
    - user: {{ jira.user }}
    - group: {{ jira.user }}
    - template: jinja
    - listen_in:
      - module: jira-restart
    - context:
      jira: {{ jira|json }}

#update-rc.d jira defaults && update-rc.d jira enable:
#  cmd.run


jira-service:
  service.running:
    - name: jira
    - enable: True
    - require:
      - archive: unpack-jira-tarball
      - file: jira-init-script
    - watch: 
      - /usr/lib/systemd/system/jira.service
      - {{ jira.prefix }}/jira/atlassian-jira/WEB-INF/classes/jira-application.properties


jira-restart:
  module.wait:
    - name: service.restart
    - m_name: jira

jira-stop:
  module.wait:
    - name: service.stop
    - m_name: jira  




#[INFO    ] Executing command ['systemd-run', '--scope', 'systemctl', 'restart', 'jira.service'] in directory '/root'





