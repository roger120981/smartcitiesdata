use Mix.Config

kafka_brokers = System.get_env("KAFKA_BROKERS")
redis_host = System.get_env("REDIS_HOST")

endpoint =
  kafka_brokers
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.map(fn entry -> String.split(entry, ":") end)
  |> Enum.map(fn [host, port] -> {String.to_atom(host), String.to_integer(port)} end)

config :smart_city_registry,
  redis: [
    host: redis_host
  ]

config :andi,
  ldap_user: System.get_env("LDAP_USER") |> Andi.LdapUtils.decode_dn!(),
  ldap_pass: System.get_env("LDAP_PASS"),
  ldap_env_ou: System.get_env("LDAP_ENV")

config :paddle, Paddle,
  host: System.get_env("LDAP_HOST"),
  base: System.get_env("LDAP_BASE")

config :andi, :brook,
  instance: :andi,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: endpoint,
      topic: "event-stream",
      group: "andi-event-stream",
      config: [
        begin_offset: :earliest
      ]
    ]
  ],
  handlers: [Andi.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [redix_args: [host: redis_host], namespace: "andi:view"]
  ]
