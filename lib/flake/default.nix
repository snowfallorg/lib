{ core-inputs
, user-inputs
, snowfall-lib
, snowfall-config
}:

let
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl filterAttrs const;
in
rec {
  flake = rec {
    # Remove the `self` attribute from an attribute set.
    # Type: Attrs -> Attrs
    # Usage: without-self { self = {}; x = true; }
    #   result: { x = true; }
    without-self = flake-inputs: builtins.removeAttrs flake-inputs [ "self" ];

    # Remove the `src` attribute from an attribute set.
    # Type: Attrs -> Attrs
    # Usage: without-src { src = ./.; x = true; }
    #   result: { x = true; }
    without-src = flake-inputs: builtins.removeAttrs flake-inputs [ "src" ];

    # Remove the `src` and `self` attributes from an attribute set.
    # Type: Attrs -> Attrs
    # Usage: without-snowfall-inputs { self = {}; src = ./.; x = true; }
    #   result: { x = true; }
    without-snowfall-inputs = snowfall-lib.fp.compose without-self without-src;

    # Remove Snowfall-specific attributes so the rest can be safely
    # passed to flake-utils-plus.
    # Type: Attrs -> Attrs
    # Usage: without-snowfall-options { src = ./.; x = true; }
    #   result: { x = true; }
    without-snowfall-options = flake-options:
      builtins.removeAttrs
        flake-options
        [
          "systems"
          "modules"
          "overlays"
          "packages"
          "outputs-builder"
          "outputsBuilder"
          "packagesPrefix"
          "hosts"
          "channels-config"
          "templates"
          "package-namespace"
          "alias"
        ];

    # Transform an attribute set of inputs into an attribute set where
    # the values are the inputs' `lib` attribute. Entries without a `lib`
    # attribute are removed.
    # Type: Attrs -> Attrs
    # Usage: get-lib { x = nixpkgs; y = {}; }
    #   result: { x = nixpkgs.lib; }
    get-libs = attrs:
      let
        # @PERF(jakehamilton): Replace filter+map with a fold.
        attrs-with-libs = filterAttrs
          (name: value: builtins.isAttrs (value.lib or null))
          attrs;
        libs =
          builtins.mapAttrs (name: input: input.lib) attrs-with-libs;
      in
      libs;
  };

  mkFlake = full-flake-options:
    let
      package-namespace = full-flake-options.package-namespace or "internal";
      custom-flake-options = flake.without-snowfall-options full-flake-options;
      alias = full-flake-options.alias or { };
      homes = snowfall-lib.home.create-homes (full-flake-options.homes or { });
      systems = snowfall-lib.system.create-systems {
        systems = (full-flake-options.systems or { });
        homes = (full-flake-options.homes or { });
      };
      hosts = snowfall-lib.attrs.merge-shallow [ (full-flake-options.systems.hosts or { }) systems homes ];
      templates = snowfall-lib.template.create-templates {
        overrides = (full-flake-options.templates or { });
        alias = alias.templates or { };
      };
      nixos-modules = snowfall-lib.module.create-modules {
        src = snowfall-lib.fs.get-snowfall-file "modules/nixos";
        overrides = (full-flake-options.modules.nixos or { });
        alias = alias.modules.nixos or { };
      };
      darwin-modules = snowfall-lib.module.create-modules {
        src = snowfall-lib.fs.get-snowfall-file "modules/darwin";
        overrides = (full-flake-options.modules.darwin or { });
        alias = alias.modules.darwin or { };
      };
      home-modules = snowfall-lib.module.create-modules {
        src = snowfall-lib.fs.get-snowfall-file "modules/home";
        overrides = (full-flake-options.modules.home or { });
        alias = alias.modules.home or { };
      };
      overlays = snowfall-lib.overlay.create-overlays {
        inherit package-namespace;
        extra-overlays = full-flake-options.extra-exported-overlays or { };
      };

      outputs-builder = channels:
        let
          user-outputs-builder =
            full-flake-options.outputs-builder
              or full-flake-options.outputsBuilder
              or (const { });
          user-outputs = user-outputs-builder channels;
          packages = snowfall-lib.package.create-packages {
            inherit channels package-namespace;
            overrides = (full-flake-options.packages or { }) // (user-outputs.packages or { });
            alias = alias.packages or { };
          };
          shells = snowfall-lib.shell.create-shells {
            inherit channels;
            overrides = (full-flake-options.shells or { }) // (user-outputs.devShells or { });
            alias = alias.shells or { };
          };

          outputs = {
            inherit packages;

            devShells = shells;
          };
        in
        snowfall-lib.attrs.merge-deep [ user-outputs outputs ];

      flake-options = custom-flake-options // {
        inherit hosts templates;
        inherit (user-inputs) self;

        lib = snowfall-lib.internal.user-lib;
        inputs = snowfall-lib.flake.without-src user-inputs;

        nixosModules = nixos-modules;
        darwinModules = darwin-modules;
        homeModules = home-modules;

        channelsConfig = full-flake-options.channels-config or { };

        channels.nixpkgs.overlaysBuilder = snowfall-lib.overlay.create-overlays-builder {
          package-namespace = full-flake-options.package-namespace or null;
          extra-overlays = full-flake-options.overlays or [ ];
        };

        outputsBuilder = outputs-builder;
      };

      flake-utils-plus-outputs =
        core-inputs.flake-utils-plus.lib.mkFlake flake-options;

      flake-outputs =
        flake-utils-plus-outputs // {
          inherit overlays;
        };
    in
    flake-outputs;
}
