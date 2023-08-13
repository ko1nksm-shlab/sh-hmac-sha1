# sh-hmac-sha1

This is hmac-sha1 implemented in a shell script.

**Note**: The implementation of `hash_sha1` was taken from [bash-totp](https://github.com/neutronscott/bash-totp) and rewritten for the POSIX shell.

## Motivation

To generate HMAC-SHA1 by shell script without revealing the secret. See below.

- [Generate HMAC in Bash without revealing the secret - unix.stackexchange.com](https://unix.stackexchange.com/questions/419826/generate-hmac-in-bash-without-revealing-the-secret)
- [openssl dgst add support for reading the hmac key from a file - github.com](https://github.com/openssl/openssl/issues/13382)
- [libkcapi - Linux Kernel Crypto API User Space Interface Library](http://www.chronox.de/libkcapi.html)

## Requirements

- POSIX shell (dash, bash, ksh, mksh, yash, zsh, etc)
- Basic commands (`od`, `tr`, and `fold`)

The `openssl` command is not required (used only for testing).

## Usage

sh-hmac-sha1 is a shell script **library**. Shell functions do not reveal secrets.

```sh
#!/bin/sh
. ./hmac-sha1.sh
hmac_sha1 "secret_key" "value" # => b75db159dc00e1e84e251a1ea6176359e7427901
hmac_sha1_bin "secret_key" "value" | base64 # => t12xWdwA4ehOJRoephdjWedCeQE=
```

Equivalent to below.

```console
$ printf '%s' "value" | openssl dgst -sha1 -hmac "secret_key"
SHA1(stdin)= b75db159dc00e1e84e251a1ea6176359e7427901

$ printf '%s' "value" | openssl dgst -sha1 -hmac "secret_key" -binary | base64
t12xWdwA4ehOJRoephdjWedCeQE=
```

The included `hmac-sha1` is just a bonus. It is an example implementation.

```console
$ printf '%s' value | ./hmac-sha1 <(printf '%s' secret_key)
b75db159dc00e1e84e251a1ea6176359e7427901

$ printf '%s' value | ./hmac-sha1 <(printf '%s' secret_key) --binary | base64
t12xWdwA4ehOJRoephdjWedCeQE=
```
