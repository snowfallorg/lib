# Snowfall Lib

<a href="https://nixos.wiki/wiki/Flakes" target="_blank">
	<img alt="Nix Flakes Ready" src="https://img.shields.io/static/v1?logo=nixos&logoColor=d8dee9&label=Nix%20Flakes&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge">
</a>
<a href="https://nixos.org" target="_blank">
	<img alt="Linux Ready" src="https://img.shields.io/static/v1?logo=linux&logoColor=d8dee9&label=Linux&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge">
</a>
<a href="https://github.com/lnl7/nix-darwin" target="_blank">
	<img alt="macOS Ready" src="https://img.shields.io/static/v1?logo=apple&logoColor=d8dee9&label=macOS&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge">
</a>
<a href="https://github.com/nix-community/nixos-generators" target="_blank">
	<img alt="Generators Ready" src="https://img.shields.io/static/v1?logo=linux-containers&logoColor=d8dee9&label=Generators&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge">
</a>

<p>
<!--
	This paragraph is not empty, it contains an em space (UTF-8 8195) on the next line in order
	to create a gap in the page.
-->
  
</p>

> Unified configuration for systems, packages, modules, shells, templates, and more with Nix Flakes.
>
> _Snowfall Lib is built on top of [flake-utils-plus](https://github.com/gytis-ivaskevicius/flake-utils-plus)._

## Get Started

1. Create a new directory to work in.

```bash
mkdir config

cd config
```

2. Create a new flake with one of the templates from [@snowfallorg/templates](https://github.com/snowfallorg/templates).

| Name      | Description                                       |
| --------- | ------------------------------------------------- |
| `system`  | A NixOS system and modules ready to modify.       |
| `package` | A Nix Flake that exports packages and an overlay. |
| `module`  | A Nix Flake that exports NixOS modules.           |
| `lib`     | A Nix Flake that exports a custom `lib`           |

```bash
# For example, to use the system template.
nix flake init -t github:snowfallorg/templates#system
```

3. See [Usage](#usage) for information on how to use and customize your flake.

## Usage

`snowfall-lib` provides two utilities directly on the flake itself.

### `mkLib`

The library generator function. This is the entrypoint for `snowfall-lib` and is how
you access all of its features. See the following Nix Flake example for how to create a
library instance with `mkLib`.

```nix
{
	description = "My Flake";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";

		snowfall-lib = {
			url = "github:snowfallorg/lib";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = inputs:
		let
			lib = inputs.snowfall-lib.mkLib {
				# You must pass in both your flake's inputs and the root directory of
				# your flake.
				inherit inputs;
				src = ./.;
			};
		in
		# We'll cover what to do here next.
		{ };
}
```

For information on how to use `lib`, see the [`lib`](#lib) section. Or skip directly
to [`lib.mkFlake`](#libmkflake) to see how to configure your flake's outputs.

### `mkFlake`

A convenience wrapper for writing the following.

```nix
let
	lib = inputs.snowfall-lib.mkLib {
		inherit inputs;
		src = ./.;
	};
in lib.mkFlake {
}
```

Instead, with `mkFlake` you can combine these calls into one like the following.

```nix
inputs.snowfall-lib.mkFlake {
	inherit inputs;
	src = ./.;
};
```

See [`lib.mkFlake`](#libmkflake) for information on how to configure your flake's outputs.

## `lib`

Snowfall Lib provides utilities for creating flake outputs as well as some
necessary helpers. In addition, `lib` is an extension of `nixpkgs.lib` and every
flake input that contains a `lib` attribute. This means that you can use `lib`
directly for all of your needs, whether they're Snowfall-related, NixPkgs-related,
or for one of the other flake inputs.

The way that `mkLib` merges libraries is by starting with the base `nixpkgs.lib` and
then merge each flake input's `lib` attribute, namespaced by the name of the input.
For example, if you have the input `flake-utils-plus` then you will be able to use
`lib.flake-utils-plus` instead of having to keep a reference to the input's lib at
`inputs.flake-utils-plus.lib`.

If you have your own library in a `lib/` directory at your flake's root, definitions
in there will automatically be imported and merged as well.

When producing flake outputs with `mkFlake` or another Snowfall `lib` utility, `lib` will
be passed in as an input. All of this together gives you easy access to a common
library of utilities and easy access to the libraries of flake inputs or your own
custom library.

### `lib.mkFlake`

The `lib.mkFlake` function creates full flake outputs. For most cases you will only
need to use this helper and the Snowfall `lib` will take care of everything else.

#### Flake Structure

Snowfall Lib has opinions about how a flake's files are laid out. This lets
`lib` do all of the busy work for you and allows you to focus on creating. Here is
the structure that `lib` expects to find at the root of your flake.

```
flake-root/
│
│ Your Nix flake.
├─ flake.nix
│
│ An optional custom library.
├─ lib/
│  │
│  │ A Nix function called with `inputs`, `snowfall-inputs`, and `lib`.
│  │ The function should return an attribute set to merge with `lib`.
│  ├─ default.nix
│  │
│  │ Any (nestable) directory name.
│  └─ **/
│     │
│     │ A Nix function called with `inputs`, `snowfall-inputs`, and `lib`.
│     │ The function should return an attribute set to merge with `lib`.
│     └─ default.nix
│
│ An optional set of packages to export.
├─ packages/
│  │
│  │ Any (nestable) directory name. The name of the directory will be the
│  │ name of the package.
│  └─ **/
│     │
│     │ A Nix package to be instantiated with `callPackage`. This file
│     │ should contain a function that takes an attribute set of packages
│     │ and *required* `lib` and returns a derivation.
│     └─ default.nix
│
│
├─ modules/ (optional modules)
│  │
│  │ Any (nestable) directory name. The name of the directory will be the
│  │ name of the module.
│  └─ **/
│     │
│     │ A NixOS module.
│     └─ default.nix
│
├─ overlays/ (optional overlays)
│  │
│  │ Any (nestable) directory name.
│  └─ **/
│     │
│     │ A custom overlay. This file should contain a function that takes three arguments:
│     │   - An attribute set of your flake's inputs and a `channels` attribute containing
│     │     all of your available channels (eg. nixpkgs, unstable).
│     │   - The final set of `pkgs`.
│     │   - The previous set of `pkgs`.
│     │
│     │ This function should return an attribute set to merge onto `pkgs`.
│     └─ default.nix
│
├─ systems/ (optional system configurations)
│  │
│  │ A directory named after the `system` type that will be used for all machines within.
│  │
│  │ The architecture is any supported architecture of NixPkgs, for example:
│  │  - x86_64
│  │  - aarch64
│  │  - i686
│  │
│  │ The format is any supported NixPkgs format *or* a format provided by either nix-darwin
│  │ or nixos-generators. However, in order to build systems with nix-darwin or nixos-generators,
│  │ you must add `darwin` and `nixos-generators` inputs to your flake respectively. Here
│  │ are some example formats:
│  │  - linux
│  │  - darwin
│  │  - iso
│  │  - install-iso
│  │  - do
│  │  - vmware
│  │
│  │ With the architecture and format together (joined by a hyphen), you get the name of the
│  │ directory for the system type.
│  └─ <architecture>-<format>/
│     │
│     │ A directory that contains a single system's configuration. The directory name
│     │ will be the name of the system.
│     └─ <system-name>/
│        │
│        │ A NixOS module for your system's configuration.
│        └─ default.nix
```

#### Default Flake

Without any extra input, `lib.mkFlake` will generate outputs for all systems, modules,
packages, overlays, and shells specified by the [Flake Structure](#flake-structure) section.

```nix
{
	description = "My Flake";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";

		snowfall-lib = {
			url = "github:snowfallorg/lib";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = inputs:
		# This is an example and in your actual flake you can use `snowfall-lib.mkFlake`
		# directly unless you explicitly need a feature of `lib`.
		let
			lib = inputs.snowfall-lib.mkLib {
				# You must pass in both your flake's inputs and the root directory of
				# your flake.
				inherit inputs;
				src = ./.;
			};
		in
			lib.mkFlake { };
}
```

#### External Overlays And Modules

You can apply overlays and modules from your flake's inputs with the following options.

```nix
{
	description = "My Flake";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";

		snowfall-lib = {
			url = "github:snowfallorg/lib";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		nix-ld = {
			url = "github:Mic92/nix-ld";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = inputs:
		# This is an example and in your actual flake you can use `snowfall-lib.mkFlake`
		# directly unless you explicitly need a feature of `lib`.
		let
			lib = inputs.snowfall-lib.mkLib {
				# You must pass in both your flake's inputs and the root directory of
				# your flake.
				inherit inputs;
				src = ./.;
			};
		in
			lib.mkFlake {
				# Add overlays for the `nixpkgs` channel.
				overlays = with inputs; [
					home-manager.overlay
				];

				# Add modules to all systems.
				systems.modules = with inputs; [
					nix-ld.nixosModules.nix-ld
				];

				# Add modules to a specific system.
				systems.hosts.my-host = with inputs; [
					nix-ld.nixosModules.nix-ld
				];
			};
}
```

#### Internal Packages And Outputs

Packages created from your `packages/` directory are automatically made available via an
overlay for your `nixpkgs` channel. System configurations can access these packages directly
on `pkgs` and consumers of your flake can use the generated `<your-flake>.overlays` attributes.

```nix
{
	description = "My Flake";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";

		snowfall-lib = {
			url = "github:snowfallorg/lib";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		comma = {
			url = "github:nix-community/comma";
			inputs.nixpkgs.follows = "unstable";
		};
	};

	outputs = inputs:
		# This is an example and in your actual flake you can use `snowfall-lib.mkFlake`
		# directly unless you explicitly need a feature of `lib`.
		let
			lib = inputs.snowfall-lib.mkLib {
				# You must pass in both your flake's inputs and the root directory of
				# your flake.
				inherit inputs;
				src = ./.;
			};
		in
			lib.mkFlake {
				# Optionally place all packages under a namespace when used in an overlay.
				# Instead of accessing packages with `pkgs.<name>`, your internal packages
				# will be available at `pkgs.<namespace>.<name>`.
				overlay-package-namespace = "my-namespace";

				# You can also pass through external packages or dynamically create new ones
				# in addition to the ones that `lib` will create from your `packages/` directory.
				outputs-builder = channels: {
					packages = {
						comma = inputs.comma.packages.${channels.nixpkgs.system}.comma;
					};
				};
			};
}
```

#### Default Packages And Shells

Snowfall Lib will create packages and shells based on your `packages/` and `shells`
directories. However, it is common to additionally map one of those packages or shells
to be their respective default. This can be achieved by using `outputs-builder` and
mapping the `default` package or shell to the name of the one you want.

```nix
{
	description = "My Flake";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";

		snowfall-lib = {
			url = "github:snowfallorg/lib";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = inputs:
		# This is an example and in your actual flake you can use `snowfall-lib.mkFlake`
		# directly unless you explicitly need a feature of `lib`.
		let
			lib = inputs.snowfall-lib.mkLib {
				# You must pass in both your flake's inputs and the root directory of
				# your flake.
				inherit inputs;
				src = ./.;
			};
		in
			lib.mkFlake {
				# You can also pass through external packages or dynamically create new ones
				# in addition to the ones that `lib` will create from your `packages/` directory.
				outputs-builder = channels: {
					packages = {
						default = "my-package";
					};

					devShells = {
						default = "my-shell";
					};
				};
			};
}
```

#### Darwin And NixOS Generators

Snowfall Lib has support for configuring macOS systems and building any output
supported by NixOS Generators. In order to use these features, your flake must
include `darwin` and/or `nixos-generators` as inputs.

```nix
{
	description = "My Flake";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";

		snowfall-lib = {
			url = "github:snowfallorg/lib";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		# In order to configure macOS systems.
		darwin = {
			url = "github:lnl7/nix-darwin";
			inputs.nixpkgs.follows = "nixpkgs";
		};

		# In order to build system images and artifacts supported by nixos-generators.
		nixos-generators = {
			url = "github:nix-community/nixos-generators";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = inputs:
		# This is an example and in your actual flake you can use `snowfall-lib.mkFlake`
		# directly unless you explicitly need a feature of `lib`.
		let
			lib = inputs.snowfall-lib.mkLib {
				# You must pass in both your flake's inputs and the root directory of
				# your flake.
				inherit inputs;
				src = ./.;
			};
		in
			# No additional configuration is required to use this feature, you only
			# have to add darwin or nixos-generators to your flake inputs.
			lib.mkFlake { };
}
```

Any macOS systems will be available on your flake at `darwinConfigurations` for use
with `darwin-rebuild`. Any system type supported by NixOS Generators will be available
on your flake at `<format>Configurations` where `<format>` is the name of the generator
type. See the following table for a list of supported formats from NixOS Generators.

| format               | description                                                                              |
| -------------------- | ---------------------------------------------------------------------------------------- |
| amazon               | Amazon EC2 image                                                                         |
| azure                | Microsoft azure image (Generation 1 / VHD)                                               |
| cloudstack           | qcow2 image for cloudstack                                                               |
| do                   | Digital Ocean image                                                                      |
| gce                  | Google Compute image                                                                     |
| hyperv               | Hyper-V Image (Generation 2 / VHDX)                                                      |
| install-iso          | Installer ISO                                                                            |
| install-iso-hyperv   | Installer ISO with enabled hyper-v support                                               |
| iso                  | ISO                                                                                      |
| kexec                | kexec tarball (extract to / and run /kexec_nixos)                                        |
| kexec-bundle         | Same as before, but it's just an executable                                              |
| kubevirt             | KubeVirt image                                                                           |
| lxc                  | Create a tarball which is importable as an lxc container, use together with lxc-metadata |
| lxc-metadata         | The necessary metadata for the lxc image to start                                        |
| openstack            | qcow2 image for openstack                                                                |
| proxmox              | [VMA](https://pve.proxmox.com/wiki/VMA) file for proxmox                                 |
| qcow                 | qcow2 image                                                                              |
| raw                  | Raw image with bios/mbr                                                                  |
| raw-efi              | Raw image with efi support                                                               |
| sd-aarch64           | Like sd-aarch64-installer, but does not use default installer image config.              |
| sd-aarch64-installer | create an installer sd card for aarch64                                                  |
| vagrant-virtualbox   | VirtualBox image for [Vagrant](https://www.vagrantup.com/)                               |
| virtualbox           | virtualbox VM                                                                            |
| vm                   | Only used as a qemu-kvm runner                                                           |
| vm-bootloader        | Same as vm, but uses a real bootloader instead of netbooting                             |
| vm-nogui             | Same as vm, but without a GUI                                                            |
| vmware               | VMWare image (VMDK)                                                                      |

### `lib.snowfall.flake`

Helpers related to Nix flakes.

#### `lib.snowfall.flake.without-self`

Remove the `self` attribute from an attribute set.

Type: `Attrs -> Attrs`

Usage:

```nix
without-self { self = {}; x = true; }
```

Result:

```nix
{ x = true; }
```

#### `lib.snowfall.flake.without-src`

Remove the `src` attribute from an attribute set.

Type: `Attrs -> Attrs`

Usage:

```nix
without-src { src = {}; x = true; }
```

Result:

```nix
{ x = true; }
```

#### `lib.snowfall.flake.without-snowfall-inputs`

Remove the `src` and `self` attributes from an attribute set.

Type: `Attrs -> Attrs`

Usage:

```nix
without-snowfall-inputs { self = {}; src = {}; x = true; }
```

Result:

```nix
{ x = true; }
```

#### `lib.snowfall.flake.get-libs`

Transform an attribute set of inputs into an attribute set where
the values are the inputs' `lib` attribute. Entries without a `lib`
attribute are removed.

Type: `Attrs -> Attrs`

Usage:

```nix
get-lib { x = nixpkgs; y = {}; }
```

Result:

```nix
{ x = nixpkgs.lib; }
```

### `lib.snowfall.path`

#### `lib.snowfall.path.split-file-extension`

Split a file name and its extension.

Type: `String -> [String]`

Usage:

```nix
split-file-extension "my-file.md"
```

Result:

```nix
[ "my-file" "md" ]
```

#### `lib.snowfall.path.has-any-file-extension`

Check if a file name has a file extension.

Type: `String -> Bool`

Usage:

```nix
has-any-file-extension "my-file.txt"
```

Result:

```nix
true
```

#### `lib.snowfall.path.get-file-extension`

Get the file extension of a file name.

Type: `String -> String`
Usage:

```nix
get-file-extension "my-file.final.txt"
```

Result:

```nix
"txt"
```

#### `lib.snowfall.path.has-file-extension`

Check if a file name has a specific file extension.

Type: `String -> String -> Bool`

Usage:

```nix
has-file-extension "txt" "my-file.txt"
```

Result:

```nix
true
```

#### `lib.snowfall.path.get-parent-directory`

Get the parent directory for a given path.

Type: `Path -> Path`

Usage:

```nix
get-parent-directory "/a/b/c"
```

Result:

```nix
"/a/b"
```

#### `lib.snowfall.path.get-file-name-without-extension`

Get the file name of a path without its extension.

Type: `Path -> String`

Usage:

```nix
get-file-name-without-extension ./some-directory/my-file.pdf
```

Result:

```nix
"my-file"
```

### `lib.snowfall.fs`

File system utilities.

#### `lib.snowfall.fs.is-file-kind`

#### `lib.snowfall.fs.is-symlink-kind`

#### `lib.snowfall.fs.is-directory-kind`

#### `lib.snowfall.fs.is-unknown-kind`

Matchers for file kinds. These are often used with `readDir`.

Type: `String -> Bool`

Usage:

```nix
is-file-kind "directory"
```

Result:

```nix
false
```

#### `lib.snowfall.fs.get-file`

Get a file path relative to the user's flake.

Type: `Path -> Path`

Usage:

```nix
get-file "systems"
```

Result:

```nix
"/user-source/systems"
```

#### `lib.snowfall.fs.internal-get-file`

Get a file relative to the Snowfall Lib flake. You probably shouldn't use this!

Type: `Path -> Path`

Usage:

```nix
get-file "systems"
```

Result:

```nix
"/snowfall-lib-source/systems"
```

#### `lib.snowfall.fs.safe-read-directory`

Safely read from a directory if it exists.

Type: `Path -> Attrs`

Usage:

```nix
safe-read-directory ./some/path
```

Result:

```nix
{ "my-file.txt" = "regular"; }
```

#### `lib.snowfall.fs.get-directories`

Get directories at a given path.

Type: `Path -> [Path]`

Usage:

```nix
get-directories ./something
```

Result:

```nix
[ "./something/a-directory" ]
```

#### `lib.snowfall.fs.get-files`

Get files at a given path.

Type: `Path -> [Path]`

Usage:

```nix
get-files ./something
```

Result:

```nix
[ "./something/a-file" ]
```

#### `lib.snowfall.fs.get-files-recursive`

Get files at a given path, traversing any directories within.

Type: `Path -> [Path]`

Usage:

```nix
get-files-recursive ./something
```

Result:

```nix
[ "./something/some-directory/a-file" ]
```

#### `lib.snowfall.fs.get-nix-files`

Get nix files at a given path.

Type: `Path -> [Path]`

Usage:

```nix
get-nix-files "./something"
```

Result:

```nix
[ "./something/a.nix" ]
```

#### `lib.snowfall.fs.get-nix-files-recursive`

Get nix files at a given path, traversing any directories within.

Type: `Path -> [Path]`

Usage:

```nix
get-nix-files "./something"
```

Result:

```nix
[ "./something/a.nix" ]
```

#### `lib.snowfall.fs.get-default-nix-files`

Get nix files at a given path named "default.nix".

Type: `Path -> [Path]`

Usage:

```nix
get-default-nix-files "./something"
```

Result:

```nix
[ "./something/default.nix" ]
```

#### `lib.snowfall.fs.get-default-nix-files-recursive`

Get nix files at a given path named "default.nix", traversing any directories within.

Type: `Path -> [Path]`

Usage:

```nix
get-default-nix-files-recursive "./something"
```

Result:

```nix
[ "./something/some-directory/default.nix" ]
```

#### `lib.snowfall.fs.get-non-default-nix-files`

Get nix files at a given path not named "default.nix".

Type: `Path -> [Path]`

Usage:

```nix
get-non-default-nix-files "./something"
```

Result:

```nix
[ "./something/a.nix" ]
```

#### `lib.snowfall.fs.get-non-default-nix-files-recursive`

Get nix files at a given path not named "default.nix", traversing any directories within.

Type: `Path -> [Path]`

Usage:

```nix
get-non-default-nix-files-recursive "./something"
```

Result:

```nix
[ "./something/some-directory/a.nix" ]
```

### `lib.snowfall.attrs`

Utilities for working with attribute sets.

#### `lib.snowfall.attrs.map-concat-attrs-to-list`

Map and flatten an attribute set into a list.

Type: `(a -> b -> [c]) -> Attrs -> [c]`

Usage:

```nix
map-concat-attrs-to-list (name: value: [name value]) { x = 1; y = 2; }
```

Result:

```nix
[ "x" 1 "y" 2 ]
```

#### `lib.snowfall.attrs.merge-deep`

Recursively merge a list of attribute sets.

Type: `[Attrs] -> Attrs`

Usage:

```nix
merge-deep [{ x = 1; } { x = 2; }]
```

Result:

```nix
{ x = 2; }
```

#### `lib.snowfall.attrs.merge-shallow`

Merge the root of a list of attribute sets.

Type: `[Attrs] -> Attrs`

Usage:

```nix
merge-shallow [{ x = 1; } { x = 2; }]
```

Result:

```nix
{ x = 2; }
```

#### `lib.snowfall.attrs.merge-shallow-packages`

Merge shallow for packages, but allow one deeper layer of attributes sets.

Type: `[Attrs] -> Attrs`

Usage:

```nix
merge-shallow-packages [
	{
		inherit (pkgs) vim;
		namespace.first = 1;
	}
	{
		inherit (unstable) vim;
		namespace.second = 2;
	}
]
```

Result:

```nix
{
	vim = {/* the vim package from the last entry */};
	namespace = {
		first = 1;
		second = 2;
	};
}
```

### `lib.snowfall.system`

#### `lib.snowfall.system.is-darwin`

Check whether a named system is macOS.

Type: `String -> Bool`

Usage:

```nix
is-darwin "x86_64-linux"
```

Result:

```nix
false
```

#### `lib.snowfall.system.is-linux`

Check whether a named system is Linux.

Type: `String -> Bool`

Usage:

```nix
is-linux "x86_64-linux"
```

Result:

```nix
false
```

#### `lib.snowfall.system.is-virtual`

Check whether a named system is virtual.

Type: `String -> Bool`

Usage:

```nix
is-linux "x86_64-iso"
```

Result:

```nix
true
```

#### `lib.snowfall.system.get-virtual-system-type`

Get the virtual system type of a system target.

Type: `String -> String`

Usage:

```nix
get-virtual-system-type "x86_64-iso"
```

Result:

```nix
"iso"
```

#### `lib.snowfall.system.get-target-systems-metadata`

Get structured data about all systems for a given target.

Type: `String -> [Attrs]`

Usage:

```nix
get-target-systems-metadata "x86_64-linux"
```

Result:

```nix
[ { target = "x86_64-linux"; name = "my-machine"; path = "/systems/x86_64-linux/my-machine"; } ]
```

#### `lib.snowfall.system.get-system-builder`

Get the system builder for a given target.

Type: `String -> Function`

Usage:

```nix
get-system-builder "x86_64-iso"
```

Result:

```nix
(args: <system>)
```

#### `lib.snowfall.system.get-system-output`

Get the flake output attribute for a system target.

Type: `String -> String`

Usage:

```nix
get-system-output "aarch64-darwin"
```

Result:

```nix
"darwinConfigurations"
```

#### `lib.snowfall.system.get-resolved-system-target`

Get the resolved (non-virtual) system target.

Type: `String -> String`

Usage:

```nix
get-resolved-system-target "x86_64-iso"
```

Result:

```nix
"x86_64-linux"
```

#### `lib.snowfall.system.create-system`

Create a system.

Type: `Attrs -> Attrs`

Usage:

```nix
create-system { path = ./systems/my-system; }
```

Result:

```nix
<flake-utils-plus-system-configuration>
```

#### `lib.snowfall.system.create-systems`

Create all available systems.

Type: `Attrs -> Attrs`

Usage:

```nix
create-systems { hosts.my-host.specialArgs.x = true; modules = [ my-shared-module ]; }
```

Result:

```nix
{ my-host = <flake-utils-plus-system-configuration>; }
```

### `lib.snowfall.package`

Utilities for working with flake packages.

#### `lib.snowfall.package.create-packages`

Create flake output packages.

Type: `Attrs -> Attrs`

Usage:

```nix
create-packages { inherit channels; src = ./my-packages; overrides = { inherit another-package; default = "my-package"; }; }
```

Result:

```nix
{ another-package = ...; my-package = ...; default = ...; }
```

### `lib.snowfall.shell`

Utilities for working with flake dev shells.

#### `lib.snowfall.shell.create-shell`

Create flake output packages.

Type: `Attrs -> Attrs`

Usage:

```nix
create-shells { inherit channels; src = ./my-shells; overrides = { inherit another-shell; default = "my-shell"; }; }
```

Result:

```nix
{ another-shell = ...; my-shell = ...; default = ...; }
```

### `lib.snowfall.overlay`

Utilities for working with channel overlays.

#### `lib.snowfall.overlay.create-overlays-builder`

Create a flake-utils-plus overlays builder.

Type: `Attrs -> Attrs -> [(a -> b -> c)]`

Usage:

```nix
create-overlays-builder { src = ./my-overlays; overlay-package-namespace = "my-packages"; extra-overlays = []; }
```

Result:

```nix
(channels: [ ... ])
```

#### `lib.snowfall.overlay.create-overlays`

Create overlays to be used for flake outputs.

Type: `Attrs -> Attrs`

Usage:

```nix
create-overlays {
	src = ./my-overlays;
	packages-src = ./my-packages;
	overlay-package-namespace = "my-namespace";
	extra-overlays = {
		my-example = final: prev: {};
	};
}
```

Result:

```nix
{
	default = final: prev: {};
	my-example = final: prev: {};
	some-overlay = final: prev: {};
}
```

### `lib.snowfall.template`

Utilities for working with flake templates.

#### `lib.snowfall.template.create-templates`

Create flake templates.

Type: `Attrs -> Attrs`

Usage:

```nix
create-templates { src = ./my-templates; overrides = { inherit another-template; default = "my-template"; }; }
```

Result:

```nix
{ another-template = ...; my-template = ...; default = ...; }
```
