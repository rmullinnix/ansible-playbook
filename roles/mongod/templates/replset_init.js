rs.initiate()
sleep(10000)
{% for host in groups['dbservers'] %}
rs.add("{{ host }}:{{ mongod_port }}")
sleep(5000)
{% endfor %}
printjson(rs.status())
