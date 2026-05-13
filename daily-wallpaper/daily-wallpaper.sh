#!/usr/bin/env bash
# Multi-source daily wallpaper for GNOME (Bing, NASA APOD, Met Museum, NASA Images, optional Unsplash).
# Shuffled deck: each successful run removes that source from the queue; when empty, reshuffle all eligible sources.
# Requires: curl, jq.
#
# Setup:
#   cp ~/.config/daily-wallpaper.env.example ~/.config/daily-wallpaper.env
#   # Set NASA_API_KEY if you include "apod" in DAILY_WALLPAPER_SOURCES (DEMO_KEY is not allowed).
#   systemctl --user enable --now daily-wallpaper.timer

set -euo pipefail

CONFIG_ENV="${HOME}/.config/daily-wallpaper.env"
if [[ -f "${CONFIG_ENV}" ]]; then
	set -a
	# shellcheck disable=SC1090
	source "${CONFIG_ENV}"
	set +a
fi

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/daily-wallpaper"
QUEUE_FILE="${STATE_DIR}/queue.json"

DAILY_WALLPAPER_SOURCES="${DAILY_WALLPAPER_SOURCES:-bing,apod,met,nasa_images}"
DAILY_WALLPAPER_KEEP_DAYS="${DAILY_WALLPAPER_KEEP_DAYS:-7}"

BING_MKT="${BING_MKT:-en-US}"
BING_IDX="${BING_IDX:-0}"
BING_IMAGE_COUNT="${BING_IMAGE_COUNT:-8}"

NASA_WALLPAPER_DEFAULT_QUERIES="moon,mars,jupiter,nebula,galaxy,hubble,apollo,ISS,earth,saturn,cassini,aurora,Milky Way"
NASA_WALLPAPER_QUERIES="${NASA_WALLPAPER_QUERIES:-${NASA_WALLPAPER_DEFAULT_QUERIES}}"
NASA_WALLPAPER_MAX_PAGE="${NASA_WALLPAPER_MAX_PAGE:-10}"
NASA_WALLPAPER_SEARCH_ATTEMPTS="${NASA_WALLPAPER_SEARCH_ATTEMPTS:-8}"
NASA_WALLPAPER_MIN_WIDTH="${NASA_WALLPAPER_MIN_WIDTH:-0}"
NASA_WALLPAPER_MIN_HEIGHT="${NASA_WALLPAPER_MIN_HEIGHT:-0}"

MET_SEARCH_QUERY="${MET_SEARCH_QUERY:-cars and engines}"
UNSPLASH_QUERY="${UNSPLASH_QUERY:-cars and engines}"

WALLPAPER_DIR="${HOME}/Pictures/daily-wallpapers"
mkdir -p "${WALLPAPER_DIR}" "${STATE_DIR}"

uri_encode() {
	jq -rn --arg s "$1" '$s|@uri'
}

_normalize_count() {
	local n="${BING_IMAGE_COUNT}"
	[[ "${n}" =~ ^[0-9]+$ ]] || n=8
	((n < 1)) && n=1
	((n > 8)) && n=8
	echo "${n}"
}

_normalize_idx() {
	local i="${BING_IDX}"
	[[ "${i}" =~ ^[0-9]+$ ]] || i=0
	((i < 0)) && i=0
	echo "${i}"
}

_normalize_keep_days() {
	local d="${DAILY_WALLPAPER_KEEP_DAYS}"
	[[ "${d}" =~ ^[0-9]+$ ]] || d=7
	((d < 1)) && d=1
	echo "${d}"
}

_nasa_key_ok() {
	[[ -n "${NASA_API_KEY:-}" ]] || return 1
	[[ "${NASA_API_KEY}" != "DEMO_KEY" ]] || return 1
	return 0
}

_shuffle_lines() {
	if command -v shuf >/dev/null 2>&1; then
		shuf
	else
		awk 'BEGIN { srand(); } { print rand() "\t" $0 }' | sort -n | cut -f2-
	fi
}

# --- Bing ---

fetch_bing_json() {
	local mkt="$1" idx="$2" n="$3"
	curl -fsSL \
		"https://www.bing.com/HPImageArchive.aspx?format=js&idx=${idx}&n=${n}&mkt=${mkt}"
}

pick_random_urlbase() {
	jq -r --argjson r "${RANDOM}" '
		(.images // [])
		| map(select((.wp // true) != false))
		| if length == 0 then (.images // []) else . end
		| if length == 0 then empty
			else .[$r % length].urlbase
			end
	'
}

resolve_bing_image_url() {
	local path="$1"
	local base="https://www.bing.com${path}"
	local suf url code
	for suf in _UHD.jpg _1920x1080.jpg _1280x720.jpg; do
		url="${base}${suf}"
		code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 30 "${url}")" || true
		if [[ "${code}" == "200" ]]; then
			echo -n "${url}"
			return 0
		fi
	done
	return 1
}

try_source_bing() {
	local n idx json path url
	n="$(_normalize_count)"
	idx="$(_normalize_idx)"
	json="$(fetch_bing_json "${BING_MKT}" "${idx}" "${n}")" || return 1
	path="$(pick_random_urlbase <<< "${json}")"
	[[ -n "${path}" ]] || return 1
	url="$(resolve_bing_image_url "${path}")" || return 1
	echo -n "${url}"
}

# --- NASA APOD (real API key required; DEMO_KEY not allowed) ---

try_source_apod() {
	_nasa_key_ok || return 1
	local json url media
	json="$(curl -fsSL "https://api.nasa.gov/planetary/apod?api_key=${NASA_API_KEY}&thumbs=true")" || return 1
	media="$(jq -r '.media_type // "image"' <<< "${json}")"
	if [[ "${media}" == "image" ]]; then
		url="$(jq -r '(.hdurl // .url) // empty' <<< "${json}")"
	elif [[ "${media}" == "video" ]]; then
		url="$(jq -r '(.thumbnail_url // "")' <<< "${json}")"
	else
		return 1
	fi
	[[ -n "${url}" && "${url}" != "null" ]] || return 1
	echo -n "${url}"
}

# --- NASA Image Library ---

_nasa_queries_nonempty() {
	local -a parts=()
	local p
	IFS=',' read -ra parts <<< "${1:-}"
	for p in "${parts[@]}"; do
		p="${p#"${p%%[![:space:]]*}"}"
		p="${p%"${p##*[![:space:]]}"}"
		[[ -n "${p}" ]] && return 0
	done
	return 1
}

pick_random_query() {
	local -a parts=()
	local cleaned=()
	local p
	IFS=',' read -ra parts <<< "${NASA_WALLPAPER_QUERIES}"
	for p in "${parts[@]}"; do
		p="${p#"${p%%[![:space:]]*}"}"
		p="${p%"${p##*[![:space:]]}"}"
		[[ -n "${p}" ]] && cleaned+=("${p}")
	done
	((${#cleaned[@]} > 0)) || return 1
	echo -n "${cleaned[$((RANDOM % ${#cleaned[@]}))]}"
}

pick_best_asset_href() {
	local min_w="${NASA_WALLPAPER_MIN_WIDTH:-0}"
	local min_h="${NASA_WALLPAPER_MIN_HEIGHT:-0}"
	[[ "${min_w}" =~ ^[0-9]+$ ]] || min_w=0
	[[ "${min_h}" =~ ^[0-9]+$ ]] || min_h=0
	jq -r --argjson minw "${min_w}" --argjson minh "${min_h}" '
		def num: if type == "number" then . elif type == "string" then (tonumber? // 0) else 0 end;
		def passes:
			(($minw == 0) or ((.width // 0 | num) >= $minw)) and
			(($minh == 0) or ((.height // 0 | num) >= $minh));
		(.links // [])
		| map(select(.href | ascii_downcase | test("\\.(jpg|jpeg|png)$")))
		| map(select(passes))
		| if length == 0 then empty
			else
				max_by([
					(if (.href | ascii_downcase | test("~large\\.")) then 1000
						elif (.href | ascii_downcase | test("~medium\\.")) then 800
						elif (.href | ascii_downcase | test("~orig\\.")) then 600
						elif (.href | ascii_downcase | test("~small\\.")) then 400
						elif (.href | ascii_downcase | test("~thumb\\.")) then 200
						else 0 end),
					((.size // 0) | num)
				])
				| .href
			end
	'
}

fetch_nasa_images_url() {
	local attempts=0
	local max_attempts="${NASA_WALLPAPER_SEARCH_ATTEMPTS}"
	local q page url json n idx item href

	while ((attempts < max_attempts)); do
		q="$(pick_random_query)" || return 1
		page=$((RANDOM % (NASA_WALLPAPER_MAX_PAGE + 1)))
		url="https://images-api.nasa.gov/search?q=$(uri_encode "${q}")&media_type=image&page=${page}"

		json="$(curl -fsSL "${url}")" || {
			((++attempts))
			continue
		}

		n="$(jq '.collection.items | length' <<< "${json}")"
		if ((n == 0)); then
			((++attempts))
			continue
		fi

		idx=$((RANDOM % n))
		item="$(jq -c --argjson i "${idx}" '.collection.items[$i]' <<< "${json}")"
		href="$(pick_best_asset_href <<< "${item}")"
		if [[ -n "${href}" ]]; then
			echo -n "${href}"
			return 0
		fi
		((++attempts))
	done
	return 1
}

try_source_nasa_images() {
	fetch_nasa_images_url
}

# --- Met Museum ---

try_source_met() {
	local json total n oid detail url maxpick qenc
	qenc="$(uri_encode "${MET_SEARCH_QUERY}")"
	json="$(curl -fsSL "https://collectionapi.metmuseum.org/public/collection/v1/search?hasImages=true&q=${qenc}")" || return 1
	total="$(jq '.total // 0' <<< "${json}")"
	((total > 0)) || return 1
	n="$(jq '[.objectIDs[]?] | length' <<< "${json}")"
	((n > 0)) || return 1
	maxpick=40
	((n > maxpick)) && n=${maxpick}
	oid="$(jq -r --argjson r "${RANDOM}" --argjson lim "${n}" '.objectIDs[0:$lim] | .[$r % length]' <<< "${json}")"
	[[ -n "${oid}" && "${oid}" != "null" ]] || return 1

	detail="$(curl -fsSL "https://collectionapi.metmuseum.org/public/collection/v1/objects/${oid}")" || return 1
	url="$(jq -r '.primaryImage // empty' <<< "${detail}")"
	[[ -n "${url}" && "${url}" != "null" ]] || return 1
	echo -n "${url}"
}

# --- Unsplash ---

try_source_unsplash() {
	[[ -n "${UNSPLASH_ACCESS_KEY:-}" ]] || return 1
	local json url qenc
	qenc="$(uri_encode "${UNSPLASH_QUERY}")"
	json="$(curl -fsSL \
		-H "Authorization: Client-ID ${UNSPLASH_ACCESS_KEY}" \
		"https://api.unsplash.com/photos/random?orientation=landscape&content_filter=high&query=${qenc}")" || return 1
	url="$(jq -r '.urls.raw // .urls.full // .urls.regular // empty' <<< "${json}")"
	[[ -n "${url}" && "${url}" != "null" ]] || return 1
	case "${url}" in
	*\?*) echo -n "${url}&w=3840&q=85" ;;
	*) echo -n "${url}?w=3840&q=85" ;;
	esac
}

# --- deck ---

parse_sources_csv() {
	local raw="${DAILY_WALLPAPER_SOURCES}"
	local -a parts=()
	local p
	IFS=',' read -ra parts <<< "${raw}"
	for p in "${parts[@]}"; do
		p="${p#"${p%%[![:space:]]*}"}"
		p="${p%"${p##*[![:space:]]}"}"
		[[ -n "${p}" ]] && printf '%s\n' "${p}"
	done
}

eligible_sources_list() {
	local -a raw=()
	local s
	local -a filtered=()
	mapfile -t raw < <(parse_sources_csv)
	if ((${#raw[@]} == 0)); then
		raw=(bing apod met nasa_images)
	fi
	for s in "${raw[@]}"; do
		case "${s}" in
		bing) filtered+=("bing") ;;
		apod)
			if _nasa_key_ok; then
				filtered+=("apod")
			else
				echo "daily-wallpaper: skipping source \"apod\" (set NASA_API_KEY; DEMO_KEY is not allowed)" >&2
			fi
			;;
		met) filtered+=("met") ;;
		nasa_images) filtered+=("nasa_images") ;;
		unsplash)
			if [[ -n "${UNSPLASH_ACCESS_KEY:-}" ]]; then
				filtered+=("unsplash")
			else
				echo "daily-wallpaper: skipping source \"unsplash\" (set UNSPLASH_ACCESS_KEY)" >&2
			fi
			;;
		*)
			echo "daily-wallpaper: unknown source \"${s}\" (ignored)" >&2
			;;
		esac
	done
	if ((${#filtered[@]} == 0)); then
		echo "daily-wallpaper: no eligible sources after filtering" >&2
		return 1
	fi
	printf '%s\n' "${filtered[@]}"
}

queue_load_remaining() {
	if [[ ! -f "${QUEUE_FILE}" ]]; then
		echo "[]"
		return 0
	fi
	jq -c '.remaining // []' "${QUEUE_FILE}" 2>/dev/null || echo "[]"
}

queue_save_remaining() {
	local json="$1"
	jq -nc --argjson r "${json}" '{remaining: $r}' >"${QUEUE_FILE}.tmp"
	mv "${QUEUE_FILE}.tmp" "${QUEUE_FILE}"
}

queue_reshuffle() {
	local -a list=()
	mapfile -t list < <(eligible_sources_list) || return 1
	((${#list[@]} > 0)) || return 1
	local shuffled
	shuffled="$(printf '%s\n' "${list[@]}" | _shuffle_lines | jq -R -s -c 'split("\n") | map(select(length>0))')"
	queue_save_remaining "${shuffled}"
	echo "${shuffled}"
}

try_source_by_name() {
	case "$1" in
	bing) try_source_bing ;;
	apod) try_source_apod ;;
	met) try_source_met ;;
	nasa_images) try_source_nasa_images ;;
	unsplash) try_source_unsplash ;;
	*) return 1 ;;
	esac
}

download_and_set_wallpaper() {
	local image_url="$1"
	local prefix="$2"
	local base ext ext_lc stamp rand dest tmp keep_days

	base="${image_url%%\?*}"
	ext="${base##*.}"
	ext_lc="$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')"
	case "${ext_lc}" in
	jpg | jpeg | png | webp | gif) ;;
	*) ext_lc="jpg" ;;
	esac

	stamp="$(date -u +%Y%m%dT%H%M%SZ)"
	rand="$(printf '%04x%04x' "${RANDOM}" "${RANDOM}")"
	dest="${WALLPAPER_DIR}/wp-${prefix}-${stamp}-${rand}.${ext_lc}"
	tmp="${dest}.part"

	curl -fsSL "${image_url}" -o "${tmp}"
	mv "${tmp}" "${dest}"

	local uri="file://${dest}"
	gsettings set org.gnome.desktop.background picture-uri "${uri}"
	gsettings set org.gnome.desktop.background picture-uri-dark "${uri}"

	keep_days="$(_normalize_keep_days)"
	find "${WALLPAPER_DIR}" -maxdepth 1 -type f \
		\( -name 'wp-*' -o -name 'bing-*' \) \
		-mtime "+${keep_days}" -delete

	echo "daily-wallpaper: set wallpaper to ${dest} (source=${prefix})"
}

main() {
	local remaining_json remaining_arr winner_idx winner_src url i src n new_rem
	remaining_json="$(queue_load_remaining)"
	n="$(jq 'length' <<< "${remaining_json}")"

	if ((n == 0)); then
		remaining_json="$(queue_reshuffle)"
		n="$(jq 'length' <<< "${remaining_json}")"
	fi

	mapfile -t remaining_arr < <(jq -r '.[]' <<< "${remaining_json}")
	((${#remaining_arr[@]} > 0)) || {
		echo "daily-wallpaper: empty source deck" >&2
		exit 1
	}

	winner_idx=-1
	winner_src=""
	url=""
	for i in "${!remaining_arr[@]}"; do
		src="${remaining_arr[i]}"
		if url="$(try_source_by_name "${src}")"; then
			winner_idx="${i}"
			winner_src="${src}"
			break
		fi
		echo "daily-wallpaper: source \"${src}\" failed, trying next" >&2
	done

	if [[ -z "${url}" ]]; then
		echo "daily-wallpaper: all sources in current deck failed" >&2
		exit 1
	fi

	download_and_set_wallpaper "${url}" "${winner_src}"

	new_rem="$(jq -c --argjson i "${winner_idx}" 'del(.[$i])' <<< "${remaining_json}")"
	queue_save_remaining "${new_rem}"
}

if ! _nasa_queries_nonempty "${NASA_WALLPAPER_QUERIES}"; then
	NASA_WALLPAPER_QUERIES="${NASA_WALLPAPER_DEFAULT_QUERIES}"
fi

main "$@"
