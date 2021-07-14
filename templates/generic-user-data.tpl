#cloud-config
# vim: syntax=yaml

final_message: "Dinivas is ready after $UPTIME seconds, Happy DINIVAS !!!"
runcmd:
  - [ sh, -c, /etc/pre-configure-dinivas.sh]
  - [ sh, -c, /etc/configure-dinivas.sh]
  - [ sh, -c, /etc/post-configure-dinivas.sh]
write_files:
-   content: |

        @@@@@@@   @@@  @@@  @@@  @@@  @@@  @@@   @@@@@@    @@@@@@
        @@@@@@@@  @@@  @@@@ @@@  @@@  @@@  @@@  @@@@@@@@  @@@@@@@
        @@!  @@@  @@!  @@!@!@@@  @@!  @@!  @@@  @@!  @@@  !@@
        !@!  @!@  !@!  !@!!@!@!  !@!  !@!  @!@  !@!  @!@  !@!
        @!@  !@!  !!@  @!@ !!@!  !!@  @!@  !@!  @!@!@!@!  !!@@!!
        !@!  !!!  !!!  !@!  !!!  !!!  !@!  !!!  !!!@!!!!   !!@!!!
        !!:  !!!  !!:  !!:  !!!  !!:  :!:  !!:  !!:  !!!       !:!
        :!:  !:!  :!:  :!:  !:!  :!:   ::!!:!   :!:  !:!      !:!
        :::: ::   ::   ::   ::   ::     ::::    ::   :::  :::: ::
        :: :  :   :    ::    :   :       :       :   : :  :: : :

        This host is managed by Dinivas :)

    path: /etc/motd
    permissions: '644'
-   content: |
        {
          "addresses": {
              "dns": "0.0.0.0",
              "grpc": "0.0.0.0",
              "http": "0.0.0.0",
              "https": "0.0.0.0"
          },
          "advertise_addr": "",
          "advertise_addr_wan": "",
          "bind_addr": "0.0.0.0",
          "bootstrap": false,
          %{ if consul_agent_mode == "server" }
          "bootstrap_expect": ${consul_server_count},
          %{ endif }
          "client_addr": "0.0.0.0",
          "data_dir": "/var/consul",
          "datacenter": "${consul_cluster_datacenter}",
          "disable_update_check": false,
          "domain": "${consul_cluster_domain}",
          "enable_local_script_checks": true,
          "enable_script_checks": false,
          "leave_on_terminate": true,
          "log_file": "/var/log/consul/consul.log",
          "log_level": "INFO",
          "log_rotate_bytes": 0,
          "log_rotate_duration": "24h",
          "log_rotate_max_files": 0,
          "node_name": "",
          "performance": {
              "leave_drain_time": "5s",
              "raft_multiplier": 1,
              "rpc_hold_timeout": "7s"
          },
          "ports": {
              "dns": 8600,
              "grpc": -1,
              "http": 8500,
              "https": -1,
              "serf_lan": 8301,
              "serf_wan": 8302,
              "server": 8300
          },
          "raft_protocol": 3,
          "retry_interval": "30s",
          "retry_interval_wan": "30s",
          %{ if cloud_provider == "openstack" ~}
          "retry_join": ["provider=os tag_key=consul_cluster_name tag_value=${consul_cluster_name} domain_name=${os_auth_domain_name} user_name=${os_auth_username} password=${os_auth_password} auth_url=${os_auth_url} project_id=${os_project_id}"],
          %{ endif }
          %{ if cloud_provider == "digitalocean" ~}
          "retry_join": ["provider=digitalocean region=${do_region} tag_name=consul_cluster_name_${consul_cluster_name}  api_token=${do_api_token}"],
          %{ endif }
          "retry_max": 0,
          "retry_max_wan": 0,
          "server": %{ if consul_agent_mode == "server" }true%{ else }false%{ endif },
          "translate_wan_addrs": false,
          "ui": %{ if consul_agent_mode == "server" }true%{ else }false%{ endif },
          "disable_host_node_id": true
        }

    owner: consul:bin
    path: /etc/consul/config.json
    permissions: '644'
%{ if enable_logging_graylog ~}
-   content: |
        [OUTPUT]
            Name                    gelf
            Match                   *
            Host                    ${project_name}-graylog
            Port                    12201
            Mode                    tcp
            Gelf_Short_Message_Key  MESSAGE

    owner: root:root
    path: /etc/td-agent-bit/gelf-output.conf
    permissions: '644'
%{ endif }
-   content: |
        server:
          logfile: "/var/log/unbound.log"
          verbosity: 1
          do-ip4: yes
          do-ip6: no
          do-udp: yes
          do-tcp: yes
          hide-identity: yes
          hide-version: yes
          harden-glue: yes
          use-caps-for-id: yes
          do-not-query-localhost: no
          domain-insecure: "${consul_cluster_domain}"
        stub-zone:
        name: "${consul_cluster_domain}"
        stub-addr: "127.0.0.1@8600"

    owner: unbound:unbound
    path: /etc/unbound/conf.d/local-consul.conf
    permissions: '644'
-   content: |
        {"service":
            {"name": "node-exporter",
            "tags": ["monitor"],
            "port": 9100
            }
        }

    owner: consul:bin
    path: /etc/consul/consul.d/node_exporter-service.json
    permissions: '644'
-   content: |
        ${indent(8, pre_configure_script)}

    path: /etc/pre-configure-dinivas.sh
    permissions: '744'
-   content: |
        #!/bin/sh

        sed -i '1inameserver 127.0.0.1' /etc/resolv.conf
        sed -i '2isearch node.${consul_cluster_domain}' /etc/resolv.conf

        #Remove Consul existing datas
        chmod -R 755 /var/consul
        rm -R /var/consul/*

        instance_ip4=$(ip addr show dev eth0 | grep inet | awk '{print $2}' | head -1 | cut -d/ -f1)
        instance_hostname=$(hostname -s)

        echo " ===> Configuring Consul"
        # Update value in consul config.json
        tmp=$(mktemp)
        jq ".advertise_addr |= \"$instance_ip4\"" /etc/consul/config.json > "$tmp" && mv -f "$tmp" /etc/consul/config.json
        jq ".advertise_addr_wan |= \"$instance_ip4\"" /etc/consul/config.json > "$tmp" && mv -f "$tmp" /etc/consul/config.json
        jq ".node_name |= \"$instance_hostname\"" /etc/consul/config.json > "$tmp" && mv -f "$tmp" /etc/consul/config.json

        echo " ===> Restart Consul"
        systemctl enable consul
        systemctl restart consul
        echo " ===> Restart Unbound"
        systemctl restart unbound
        %{ if enable_logging_graylog ~}
        echo " ===> Restart TD-AGENT"
        systemctl restart td-agent-bit
        %{ endif }

    path: /etc/configure-dinivas.sh
    permissions: '744'
-   content: |
        ${indent(8, post_configure_script)}

    path: /etc/post-configure-dinivas.sh
    permissions: '744'
${custom_write_files_block}