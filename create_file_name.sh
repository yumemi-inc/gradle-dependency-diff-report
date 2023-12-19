function create_file_name() {
  sha="$(echo -n "${1}-${2}-${3}" | openssl sha1 | awk '{print $2}')"
  echo -n "${sha}.txt"
}
