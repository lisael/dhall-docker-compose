let map =
      https://raw.githubusercontent.com/dhall-lang/dhall-lang/master/Prelude/List/map

let Entry =
      https://raw.githubusercontent.com/dhall-lang/dhall-lang/master/Prelude/Map/Entry

let types = ./compose/v3/types.dhall

let defaults = ./compose/v3/defaults.dhall

let logging =
      Some
      { driver =
          "syslog"
      , options =
          Some
          [ { mapKey =
                "syslog-address"
            , mapValue =
                Some
                ( types.StringOrNumber.String
                  "udp://logs.papertrailapp.com:50183"
                )
            }
          , { mapKey =
                "tag"
            , mapValue =
                Some (types.StringOrNumber.String "{{.Name}}")
            }
          ]
      }

let nginxService =
          defaults.Service
        ⫽ { image =
              Some "recipeyak/nginx:latest"
          , ports =
              Some [ types.StringOrNumber.String "80:80" ]
          , volumes =
              Some
              [ "react-static-files:/var/app/dist"
              , "django-static-files:/var/app/django/static"
              ]
          , logging =
              logging
          , depends_on =
              Some [ "django", "react" ]
          }
      : types.Service

let djangoService =
          defaults.Service
        ⫽ { restart =
              Some "always"
          , image =
              Some "recipeyak/django:latest"
          , env_file =
              Some (types.StringOrList.List [ ".env-production" ])
          , command =
              Some (types.StringOrList.String "sh bootstrap-prod.sh")
          , volumes =
              Some [ "django-static-files:/var/app/static-files" ]
          , logging =
              logging
          , depends_on =
              Some [ "db" ]
          }
      : types.Service

let dbService =
          defaults.Service
        ⫽ { image =
              Some "postgres:10.1"
          , command =
              Some
              ( types.StringOrList.List
                [ "-c"
                , "shared_preload_libraries=\"pg_stat_statements\""
                , "-c"
                , "pg_stat_statements.max=10000"
                , "-c"
                , "pg_stat_statements.track=all"
                ]
              )
          , ports =
              Some [ types.StringOrNumber.String "5432:5432" ]
          , logging =
              logging
          , volumes =
              Some [ "pgdata:/var/lib/postgresql/data/" ]
          }
      : types.Service

let reactService =
          defaults.Service
        ⫽ { image =
              Some "recipeyak/react:latest"
          , command =
              Some (types.StringOrList.String "sh bootstrap.sh")
          , env_file =
              Some (types.StringOrList.List [ ".env-production" ])
          , volumes =
              Some [ "react-static-files:/var/app/dist" ]
          , logging =
              logging
          }
      : types.Service

let toEntry =
        λ(name : Text)
      → { mapKey =
            name
        , mapValue =
            Some (defaults.Volume ⫽ { driver = Some "local" })
        }

let Output : Type = Entry Text (Optional types.Volume)

let volumes
    : types.Volumes
    = map
      Text
      Output
      toEntry
      [ "pgdata", "django-static-files", "react-static-files" ]

let services
    : types.Services
    = [ { mapKey = "nginx", mapValue = nginxService }
      , { mapKey = "db", mapValue = dbService }
      , { mapKey = "react", mapValue = reactService }
      , { mapKey = "django", mapValue = djangoService }
      ]

in      defaults.ComposeConfig
      ⫽ { services = Some services, volumes = Some volumes }
    : types.ComposeConfig
