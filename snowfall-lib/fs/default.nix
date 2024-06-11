{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}: let
  inherit (builtins) readDir pathExists;
  inherit (core-inputs) flake-utils-plus;
  inherit (core-inputs.nixpkgs.lib) assertMsg filterAttrs mapAttrsToList flatten;

  file-name-regex = "(.*)\\.(.*)$";
in {
  fs = rec {
    ## Matchers for file kinds. These are often used with `readDir`.
    ## Example Usage:
    ## ```nix
    ## is-file-kind "directory"
    ## ```
    ## Result:
    ## ```nix
    ## false
    ## ```
    #@ String -> Bool
    is-file-kind = kind: kind == "regular";
    is-symlink-kind = kind: kind == "symlink";
    is-directory-kind = kind: kind == "directory";
    is-unknown-kind = kind: kind == "unknown";

    ## Get a file path relative to the user's flake.
    ## Example Usage:
    ## ```nix
    ## get-file "systems"
    ## ```
    ## Result:
    ## ```nix
    ## "/user-source/systems"
    ## ```
    #@ String -> String
    get-file = path: "${user-inputs.src}/${path}";

    ## Get a file path relative to the user's snowfall directory.
    ## Example Usage:
    ## ```nix
    ## get-snowfall-file "systems"
    ## ```
    ## Result:
    ## ```nix
    ## "/user-source/snowfall-dir/systems"
    ## ```
    #@ String -> String
    get-snowfall-file = path: "${snowfall-config.root}/${path}";

    ## Get a file path relative to the this flake.
    ## Example Usage:
    ## ```nix
    ## get-file "systems"
    ## ```
    ## Result:
    ## ```nix
    ## "/user-source/systems"
    ## ```
    #@ String -> String
    internal-get-file = path: "${core-inputs.src}/${path}";

    ## Safely read from a directory if it exists.
    ## Example Usage:
    ## ```nix
    ## safe-read-directory ./some/path
    ## ```
    ## Result:
    ## ```nix
    ## { "my-file.txt" = "regular"; }
    ## ```
    #@ Path -> Attrs
    safe-read-directory = path:
      if pathExists path
      then readDir path
      else {};

    ## Get directories at a given path.
    ## Example Usage:
    ## ```nix
    ## get-directories ./something
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a-directory" ]
    ## ```
    #@ Path -> [Path]
    get-directories = path: let
      entries = safe-read-directory path;
      filtered-entries = filterAttrs (name: kind: is-directory-kind kind) entries;
    in
      mapAttrsToList (name: kind: "${path}/${name}") filtered-entries;

    ## Get files at a given path.
    ## Example Usage:
    ## ```nix
    ## get-files ./something
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a-file" ]
    ## ```
    #@ Path -> [Path]
    get-files = path: let
      entries = safe-read-directory path;
      filtered-entries = filterAttrs (name: kind: is-file-kind kind) entries;
    in
      mapAttrsToList (name: kind: "${path}/${name}") filtered-entries;

    ## Get files at a given path, traversing any directories within.
    ## Example Usage:
    ## ```nix
    ## get-files-recursive ./something
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/some-directory/a-file" ]
    ## ```
    #@ Path -> [Path]
    get-files-recursive = path: let
      entries = safe-read-directory path;
      filtered-entries =
        filterAttrs
        (name: kind: (is-file-kind kind) || (is-directory-kind kind))
        entries;
      map-file = name: kind: let
        path' = "${path}/${name}";
      in
        if is-directory-kind kind
        then get-files-recursive path'
        else path';
      files =
        snowfall-lib.attrs.map-concat-attrs-to-list
        map-file
        filtered-entries;
    in
      files;

    ## Get nix files at a given path.
    ## Example Usage:
    ## ```nix
    ## get-nix-files "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a.nix" ]
    ## ```
    #@ Path -> [Path]
    get-nix-files = path:
      builtins.filter
      (snowfall-lib.path.has-file-extension "nix")
      (get-files path);

    ## Get nix files at a given path, traversing any directories within.
    ## Example Usage:
    ## ```nix
    ## get-nix-files "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a.nix" ]
    ## ```
    #@ Path -> [Path]
    get-nix-files-recursive = path:
      builtins.filter
      (snowfall-lib.path.has-file-extension "nix")
      (get-files-recursive path);

    ## Get nix files at a given path named "default.nix".
    ## Example Usage:
    ## ```nix
    ## get-default-nix-files "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/default.nix" ]
    ## ```
    #@ Path -> [Path]
    get-default-nix-files = path:
      builtins.filter
      (name: builtins.baseNameOf name == "default.nix")
      (get-files path);

    ## Get nix files at a given path named "default.nix", traversing any directories within.
    ## Example Usage:
    ## ```nix
    ## get-default-nix-files-recursive "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/some-directory/default.nix" ]
    ## ```
    #@ Path -> [Path]
    get-default-nix-files-recursive = path:
      builtins.filter
      (name: builtins.baseNameOf name == "default.nix")
      (get-files-recursive path);

    ## Get nix files at a given path not named "default.nix".
    ## Example Usage:
    ## ```nix
    ## get-non-default-nix-files "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/a.nix" ]
    ## ```
    #@ Path -> [Path]
    get-non-default-nix-files = path:
      builtins.filter
      (
        name:
          (snowfall-lib.path.has-file-extension "nix" name)
          && (builtins.baseNameOf name != "default.nix")
      )
      (get-files path);

    ## Get nix files at a given path not named "default.nix", traversing any directories within.
    ## Example Usage:
    ## ```nix
    ## get-non-default-nix-files-recursive "./something"
    ## ```
    ## Result:
    ## ```nix
    ## [ "./something/some-directory/a.nix" ]
    ## ```
    #@ Path -> [Path]
    get-non-default-nix-files-recursive = path:
      builtins.filter
      (
        name:
          (snowfall-lib.path.has-file-extension "nix" name)
          && (builtins.baseNameOf name != "default.nix")
      )
      (get-files-recursive path);
  };
}
