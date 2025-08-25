{ config
, lib
, pkgs
, ...
}:

let

  cfg = config.services.conky;

in
{
  meta.maintainers = [ lib.hm.maintainers.kaleo ];

  options = {
    services.conky = {
      enable = lib.mkEnableOption "Conky, a light-weight system monitor";

      package = lib.mkPackageOption pkgs "conky" { };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Configuration used by the Conky daemon. Check
          <https://github.com/brndnmtthws/conky/wiki/Configurations> for
          options. If not set, the default configuration, as described by
          {command}`conky --print-config`, will be used.
        '';
      };
      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Conky automatically at login";
      };
      configs = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
          options = {
            enable = lib.mkEnableOption "this conky instance" // { default = true; };

            autoStart = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Start this conky instance automatically at login.";
            };

            config = lib.mkOption {
              type = lib.types.either lib.types.path lib.types.lines;
              description = "The conky configuration content as a string or a path to the config file.";
              example = ''
                conky.config = {
                  alignment = "top_right",
                  ...
                };
              '';
            };

            package = lib.mkOption {
              type = with lib.types; nullOr package;
              default = null;
              defaultText = lib.literalExpression "config.services.conky.package";
              description = "The conky package to use for this instance.";
              example = lib.literalExpression "pkgs.conky-lua";
            };

          };
        }));
        default = { };
        description = "A set of named Conky configurations for running multiple instances.";
        example = lib.literalExpression ''
          {
            main = {
              autoStart = true;
              config = /path/to/main.conf;
            };
            stats = {
              autoStart = false;
              config = \'\'
                conky.config = { ... };
              \'\';
              package = pkgs.conky-lua;
            };
          }
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [ (lib.hm.assertions.assertPlatform "services.conky" pkgs lib.platforms.linux) ];

    home.packages = lib.unique (
      [ cfg.package ]
      ++ (lib.map (conf: conf.package) (lib.attrValues (
        lib.filterAttrs (name: conf: conf.enable) cfg.configs
      )))
    );

    systemd.user.services =
      let
        enabledConfigs = lib.filterAttrs (name: conf: conf.enable) cfg.configs;
        conkies = lib.mapAttrs'
          (name: conf:
            let
              maybeConf = conf.config;
              isPath = lib.isString maybeConf && builtins.pathExists maybeConf;
              configFile = if isPath then maybeConf else pkgs.writeText "conky-${name}.conf" maybeConf;
            in
            {
              name = "conky@${name}";
              value = {
                Unit = lib.mkIf conf.autoStart {
                  Description = "Conky - Lightweight system monitor (${name})";
                  After = [ "graphical-session.target" ];
                  PartOf = [ "graphical-session.target" ];
                };
                Service = {
                  Restart = "always";
                  RestartSec = "3";
                  ExecStart = "${conf.package}/bin/conky --config ${configFile}";
                };
                Install = lib.mkIf conf.autoStart {
                  WantedBy = [ "graphical-session.target" ];
                };
              };
            }
          )
          enabledConfigs;

        conky = {
          Unit = {
            Description = "Conky - Lightweight system monitor";
            After = [ "graphical-session.target" ];
          };

          Service = {
            Restart = "always";
            RestartSec = "3";
            ExecStart = toString (
              [ "${cfg.package}/bin/conky" ]
              ++ lib.optional (cfg.extraConfig != "") "--config ${pkgs.writeText "conky.conf" cfg.extraConfig}"
            );
          };

          Install.WantedBy = lib.mkIf cfg.autoStart [ "graphical-session.target" ];
        };
      in
      conky // conkies;
  };
}
