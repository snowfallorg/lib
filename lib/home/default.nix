{ core-inputs, user-inputs, snowfall-lib }:

let
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl head tail concatMap optionalAttrs mkIf filterAttrs mapAttrs' mkMerge mapAttrsToList optionals mkDefault mkAliasDefinitions;

  user-homes-root = snowfall-lib.fs.get-snowfall-file "homes";
  user-modules-root = snowfall-lib.fs.get-snowfall-file "modules";
in
{
  home = rec {
    # Modules in home-manager expect `hm` to be available directly on `lib` itself.
    home-lib = snowfall-lib.internal.system-lib.extend (final: prev:
      # @NOTE(jakehamilton): This order is important, this library's extend and other utilities must write
      # _over_ the original `system-lib`.
      snowfall-lib.internal.system-lib
      // prev
      // {
        hm = snowfall-lib.internal.system-lib.home-manager.hm;
      });

    split-user-and-host = target:
      let
        raw-name-parts = builtins.split "@" target;
        name-parts = builtins.filter builtins.isString raw-name-parts;

        user = builtins.elemAt name-parts 0;
        host =
          if builtins.length name-parts > 1 then
            builtins.elemAt name-parts 1
          else
            "";
      in
      {
        inherit user host;
      };


    create-home =
      { path
      , name ? builtins.unsafeDiscardStringContext (snowfall-lib.system.get-inferred-system-name path)
      , modules ? [ ]
      , specialArgs ? { }
      , channelName ? "nixpkgs"
      , system ? "x86_64-linux"
      }:
      let
        user-metadata = split-user-and-host name;

        # @NOTE(jakehamilton): home-manager has trouble with `pkgs` recursion if it isn't passed in here.
        pkgs = user-inputs.self.pkgs.${system}.${channelName} // { lib = home-lib; };
        lib = home-lib;
      in
      assert assertMsg (user-inputs ? home-manager) "In order to create home-manager configurations, you must include `home-manager` as a flake input.";
      assert assertMsg (user-metadata.host != "") "Snowfall Lib homes must be named with the format: user@system";
      {
        inherit channelName system;

        output = "homeConfigurations";

        modules = [
          path
          ../../modules/home/user/default.nix
        ] ++ modules;

        specialArgs = {
          inherit name;
          inherit (user-metadata) user host;

          format = "home";

          inputs = snowfall-lib.flake.without-src user-inputs;

          # @NOTE(jakehamilton): home-manager has trouble with `pkgs` recursion if it isn't passed in here.
          inherit pkgs lib;
        };

        builder = args:
          user-inputs.home-manager.lib.homeManagerConfiguration
            ((builtins.removeAttrs args [ "system" "specialArgs" ]) // {
              inherit pkgs lib;

              modules = args.modules ++ [
                (module-args: import ./nix-registry-module.nix (module-args // {
                  inherit user-inputs core-inputs;
                }))
                ({
                  snowfallorg.user.name = mkDefault user-metadata.user;
                })
              ];

              extraSpecialArgs = specialArgs // args.specialArgs;
            });
      };

    get-target-homes-metadata = target:
      let
        homes = snowfall-lib.fs.get-directories target;
        existing-homes = builtins.filter (home: builtins.pathExists "${home}/default.nix") homes;
        create-home-metadata = path: {
          path = "${path}/default.nix";
          # We are building flake outputs based on file contents. Nix doesn't like this
          # so we have to explicitly discard the string's path context to allow us to
          # use the name as a variable.
          name = builtins.unsafeDiscardStringContext (builtins.baseNameOf path);
          # We are building flake outputs based on file contents. Nix doesn't like this
          # so we have to explicitly discard the string's path context to allow us to
          # use the name as a variable.
          system = builtins.unsafeDiscardStringContext (builtins.baseNameOf target);
        };
        home-configurations = builtins.map create-home-metadata existing-homes;
      in
      home-configurations;

    # Create all available homes.
    # Type: Attrs -> Attrs
    # Usage: create-homes { users."my-user@my-system".specialArgs.x = true; modules = [ my-shared-module ]; }
    #   result: { "my-user@my-system" = <flake-utils-plus-home-configuration>; }
    create-homes = homes:
      let
        targets = snowfall-lib.fs.get-directories user-homes-root;
        target-homes-metadata = concatMap get-target-homes-metadata targets;

        user-home-modules = snowfall-lib.module.create-modules {
          src = "${user-modules-root}/home";
        };

        user-home-modules-list = builtins.attrValues user-home-modules;

        create-home' = home-metadata:
          let
            inherit (home-metadata) name;
            overrides = homes.users.${name} or { };
          in
          {
            "${name}" = create-home (overrides // home-metadata // {
              modules = user-home-modules-list ++ (homes.users.${name}.modules or [ ]) ++ (homes.modules or [ ]);
            });
          };

        created-homes = foldl (homes: home-metadata: homes // (create-home' home-metadata)) { } target-homes-metadata;
      in
      created-homes;

    create-home-system-modules = users:
      let
        created-users = create-homes users;
        extra-special-args-module =
          args@{ config
          , pkgs
          , system ? pkgs.system
          , target ? system
          , format ? "home"
          , host ? ""
          , virtual ? (snowfall-lib.system.is-virtual target)
          , systems ? { }
          , ...
          }:
          {
            _file = "virtual:snowfallorg/home/extra-special-args";

            config = {
              home-manager.extraSpecialArgs = {
                inherit system target format virtual systems host;

                lib = home-lib;

                inputs = snowfall-lib.flake.without-src user-inputs;
              };
            };
          };
        system-modules = builtins.map
          (name:
            let
              created-user = created-users.${name};
              user-module = head created-user.modules;
              other-modules = tail created-user.modules;
              user-name = created-user.specialArgs.user;
            in
            args@{ config
            , pkgs
            , host ? ""
            , ...
            }:
            let
              host-matches = created-user.specialArgs.host == host;

              # @NOTE(jakehamilton): We *must* specify named attributes here in order
              # for home-manager to provide them.
              wrapped-user-module = home-args@{ pkgs, lib, osConfig ? {}, ... }:
                let
                  user-module-result = import user-module home-args;
                  user-imports = 
                    if user-module-result ? imports then
                      user-module-result.imports
                    else
                      [ ];
                  user-config =
                    if user-module-result ? config then
                      user-module-result.config
                    else
                      builtins.removeAttrs user-module-result [ "imports" "options" "_file" ];
                  user = created-user.specialArgs.user;
                in
                {
                  _file = builtins.toString user-module;
                  imports = user-imports;

                  config = mkMerge [
                    user-config
                    ({
                      snowfallorg.user.name = mkDefault user;
                    })
                    (osConfig.snowfallorg.home.resolvedHomes.${user} or {})
                  ];
                };
            in
            {
              _file = "virtual:snowfallorg/home/user/${name}";

              config = mkIf host-matches {
                home-manager = {
                  users.${user-name} = wrapped-user-module;
                  sharedModules = other-modules;
                };
              };
            }
          )
          (builtins.attrNames created-users);
      in
      [ extra-special-args-module ] ++ system-modules;
  };
}
