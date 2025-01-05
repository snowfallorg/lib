args @ {
  pkgs,
  lib,
  options,
  config,
  ...
}: let
  inherit
    (lib)
    types
    mkOption
    mkDefault
    mkRenamedOptionModule
    foldl
    optionalAttrs
    optional
    ;

  cfg = config.snowfallorg;

  inputs = args.inputs or {};

  user-names = builtins.attrNames cfg.users;

  create-system-users = system-users: name: let
    user = cfg.users.${name};
  in
    system-users
    // (optionalAttrs user.create {
      ${name} = {
        isNormalUser = mkDefault true;

        name = mkDefault name;

        home = mkDefault user.home.path;
        group = mkDefault "users";

        extraGroups = optional user.admin "wheel";
      };
    });
in {
  imports = [
    (mkRenamedOptionModule ["snowfallorg" "user"] ["snowfallorg" "users"])
  ];

  options.snowfallorg = {
    users = mkOption {
      description = "User configuration.";
      default = {};
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          create = mkOption {
            description = "Whether to create the user automatically.";
            type = types.bool;
            default = true;
          };

          admin = mkOption {
            description = "Whether the user should be added to the wheel group.";
            type = types.bool;
            default = true;
          };

          home = {
            enable = mkOption {
              type = types.bool;
              default = true;
            };

            path = mkOption {
              type = types.str;
              default = "/home/${name}";
            };

            config = mkOption {
              # HM-compatible options taken from:
              # https://github.com/nix-community/home-manager/blob/0ee5ab611dc1fbb5180bd7d88d2aeb7841a4d179/nixos/common.nix#L14
              # NOTE: This has been adapted to support documentation generation without
              # having home-manager options fully declared.
              type = types.submoduleWith {
                specialArgs =
                  {
                    osConfig = config;
                    modulesPath = "${inputs.home-manager or "/"}/modules";
                  }
                  // (config.home-manager.extraSpecialArgs or {});
                modules =
                  [
                    ({
                      lib,
                      modulesPath,
                      ...
                    }:
                      if inputs ? home-manager
                      then {
                        imports = import "${modulesPath}/modules.nix" {
                          inherit pkgs lib;
                          useNixpkgsModule = !(config.home-manager.useGlobalPkgs or false);
                        };

                        config = {
                          submoduleSupport.enable = true;
                          submoduleSupport.externalPackageInstall = config.home-manager.useUserPackages;

                          home.username = config.users.users.${name}.name;
                          home.homeDirectory = config.users.users.${name}.home;

                          nix.package = config.nix.package;
                        };
                      }
                      else {})
                  ]
                  ++ (config.home-manager.sharedModules or []);
              };
            };
          };
        };
      }));
    };
  };

  config = {
    users.users = foldl create-system-users {} user-names;
  };
}
