# shellcheck shell=sh

uint32_bin() {
  set -- "$1" $(($2 & 0xFFFFFFFF)) 31 ""
  [ "$2" -lt 0 ] && set -- "$1" $((0x7FFFFFFF - (${2#-} - 1))) $(($3 - 1)) "$4"
  while [ "$3" -ge 0 ]; do
    set -- "$1" $(($2 / 2)) $(($3 - 1)) "$(($2 % 2))$4"
  done
  [ ${#4} -eq 31 ] && set -- "$1" "$2" "$3" "1$4"
  eval "$1=\$4"
}

uint32_hex() {
  set -- "$1" $(($2 & 0xFFFFFFFF)) 0 7 ""
  [ "$2" -lt 0 ] && set -- "$1" $((0x7FFFFFFF - (${2#-} - 1))) 8 "$4" "$5"
  while [ "$4" -ge 0 ]; do
    set -- "$1" $(($2 | (($4 == 0) * $3) )) "$3" "$4" "$5"
    case $(($2 % 16)) in
      ?) set -- "$1" $(($2 / 16)) "$3" $(($4 - 1)) "$(($2 % 16))$5" ;;
      10) set -- "$1" $(($2 / 16)) "$3" $(($4 - 1)) "a$5" ;;
      11) set -- "$1" $(($2 / 16)) "$3" $(($4 - 1)) "b$5" ;;
      12) set -- "$1" $(($2 / 16)) "$3" $(($4 - 1)) "c$5" ;;
      13) set -- "$1" $(($2 / 16)) "$3" $(($4 - 1)) "d$5" ;;
      14) set -- "$1" $(($2 / 16)) "$3" $(($4 - 1)) "e$5" ;;
      15) set -- "$1" $(($2 / 16)) "$3" $(($4 - 1)) "f$5" ;;
    esac
  done
  eval "$1=\$5"
}

str2hex() {
  # Avoid executing printf external command with mksh
  # All ksh compatible shells have a print internal command
  if [ "${KSH_VERSION:-}" ]; then
    print -nr -- "$1"
  else
    printf '%s' "$1"
  fi | LC_ALL=C od -v -An -tx1 | LC_ALL=C tr -d ' \n'
}

hex2str() {
  set -- "$1" ""
  while [ "$1" ]; do
    set -- "${1#??}" "$2" "0x${1%"${1#??}"}"
    set -- "$1" "$2\\$(( $3 / 64 ))$(( ($3 % 64) / 8 ))$(( $3 % 8 ))"
  done
  printf "$2"
}

hmac_sha1_binary() {
  hex2str "$(hmac_sha1 "$1" "$2")"
}

hmac_sha1_base64() {
  (
    unset hmac base64 len chunk bits bin n
    hmac=$(hmac_sha1 "$1" "$2")
    set -- 0 1 2 3 4 5 6 7 8 9 + /
    set -- a b c d e f g h i j k l m n o p q r s t u v w x y z "$@"
    set -- A B C D E F G H I J K L M N O P Q R S T U V W X Y Z "$@"
    base64='' len=$(( ${#hmac} % 6 ))
    [ "$len" -eq 2 ] && hmac="${hmac}0000"
    [ "$len" -eq 4 ] && hmac="${hmac}00"
    while [ "$hmac" ]; do
      chunk=${hmac%"${hmac#??????}"} && hmac=${hmac#??????}
      uint32_bin bits $((0x$chunk))
      bits=${bits#00000000}
      while [ "$bits" ]; do
        bin=${bits%"${bits#??????}"} && bits=${bits#??????}
        n=0
        while [ "$bin" ]; do
          n=$(( (n * 2) + ${bin%"${bin#?}"} )) && bin=${bin#?}
        done
        eval "base64=\${base64}\${$((n + 1))}"
      done
    done
    [ "$len" -eq 2 ] && base64="${base64%??}=="
    [ "$len" -eq 4 ] && base64="${base64%?}="
    echo "$base64"
  )
}

##########################################################################
# HMAC-SHA1 in POSIX shell
# Reference implementation from: https://en.wikipedia.org/wiki/HMAC
##########################################################################
hmac_sha1() {
  (
    unset key msg i hex ipad opad
    key=$1 msg=$2 i='' hex='' ipad='' opad=''
    key=$(str2hex "$key")
    msg=$(str2hex "$msg")

    # Compute the block sized key
    #   key needs to be same as sha1 blocksize
    if [ ${#key} -gt 128 ]; then
      key=$(hash_sha1 "$key")
    fi
    while [ ${#key} -lt 128 ]; do
      key="${key}00"
    done

    # xor key 32-bit at a time
    set --
    while [ "$key" ]; do
      set -- "$@" "${key%"${key#????????}"}"
      key=${key#????????}
    done
    for i in "$@"; do
      uint32_hex hex $(( ( 0x$i ^ 0x5C5C5C5C ) & 0xFFFFFFFF ))
      opad="${opad}${hex}" # Outer padded key
    done
    for i in "$@"; do
      uint32_hex hex $(( ( 0x$i ^ 0x36363636 ) & 0xFFFFFFFF ))
      ipad="${ipad}${hex}" # Inner padded key
    done

    hash_sha1 "${opad}$(hash_sha1 "${ipad}${msg}")"
  )
}

##########################################################################
# SHA-1 in POSIX shell
# Reference implementation from: https://en.wikipedia.org/wiki/SHA-1
##########################################################################
hash_sha1() {
  (
    unset pad len

    # Pre-processing:
    pad=80 len=${#1}
    until [ $(( (len + ${#pad}) % 128 )) -eq 112 ]; do
      pad="${pad}00"
    done
    # The message size is limited to 4GB, but would be large enough
    uint32_hex len $((len << 2))
    echo "${1}${pad}00000000${len}"
  ) | LC_ALL=C fold -w128 | ( # 128 hex chars = 512-bit chunks
    unset h0 h1 h2 h3 h4 chunk temp a b c d e i m f k w
    i=0
    while [ "$i" -lt 80 ]; do
      unset "w$i"
      i=$((i + 1))
    done

    m=$((0xFFFFFFFF)) # 32-bit mask

    # Initialize variables:
    h0=$((0x67452301))
    h1=$((0xEFCDAB89))
    h2=$((0x98BADCFE))
    h3=$((0x10325476))
    h4=$((0xC3D2E1F0))

    # Process the message in successive 512-bit chunks:
    while IFS= read -r chunk; do
      i=0
      while [ "$chunk" ]; do
        # convert to 32-bit int now
        : $((w$i = 0x${chunk%"${chunk#????????}"} ))
        chunk=${chunk#????????}
        i=$((i + 1))
      done

      # Message schedule:
      #   extend the sixteen 32-bit words into eighty 32-bit words:
      while [ "$i" -le 79 ]; do
        : $((w = w$((i-3)) ^ w$((i-8)) ^ w$((i-14)) ^ w$((i-16)) ))
        # left rotate 1 with shift
        if [ "$w" -lt 0 ]; then
          # Workaround for unsigned 32-bit integer shell (e.g. mksh)
          w=$(( ((w & 0x7FFFFFFF) >> 31) | (w << 1) | 1 ))
        else
          w=$(( (w >> 31) | ((w & 0x7FFFFFFF) << 1) ))
        fi
        : $((w$i = w))
        i=$((i + 1))
      done

      # Initialize hash value for this chunk:
      a=$h0 b=$h1 c=$h2 d=$h3 e=$h4

      # Main loop:
      i=0
      while [ "$i" -le 79 ]; do
        if [ "$i" -le 19 ]; then
          k=$((0x5A827999)) f=$(( ( b & c ) | (~b & d) ))
        elif [ "$i" -le 39 ]; then
          k=$((0x6ED9EBA1)) f=$(( b ^ c ^ d ))
        elif [ "$i" -le 59 ]; then
          k=$((0x8F1BBCDC)) f=$(( (b & c) | (b & d) | (c & d) ))
        else
          k=$((0xCA62C1D6)) f=$(( b ^ c ^ d ))
        fi
        temp=$(( ( ( (a << 5) | ((a >> 27) & 0x1F) ) + f + e + k + w$i ) & m ))
        e=$d
        d=$c
        c=$(( ( (b >> 2) & 0x3FFFFFFF) | (b << 30) ))
        b=$a
        a=$temp
        i=$((i + 1))
      done

      # Add this chunk's hash to result so far:
      h0=$(( ( h0 + a ) & m ))
      h1=$(( ( h1 + b ) & m ))
      h2=$(( ( h2 + c ) & m ))
      h3=$(( ( h3 + d ) & m ))
      h4=$(( ( h4 + e ) & m ))
    done

    # Produce the final hash value (big-endian) as a 160-bit number:
    uint32_hex h0 "$h0"
    uint32_hex h1 "$h1"
    uint32_hex h2 "$h2"
    uint32_hex h3 "$h3"
    uint32_hex h4 "$h4"
    echo "${h0}${h1}${h2}${h3}${h4}"
  )
}
