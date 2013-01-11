# Report mail count for your mailbox type

TMUX_POWERLINE_SEG_MAILCOUNT_MAILDIR_INBOX_DEFAULT="$HOME/.mail/inbox/new"
TMUX_POWERLINE_SEG_MAILCOUNT_MBOX_INBOX_DEFAULT="${MAIL}"
TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_SERVER_DEFAULT="gmail.com"
TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_INTERVAL_DEFAULT="5"


generate_segmentrc() {
	read -d '' rccontents  << EORC
# Mailbox type to use. Can be any of {apple_mail, gmail, maildir, mbox}
export TMUX_POWERLINE_SEG_MAILCOUNT_MAILBOX_TYPE=""

## Gmail
# Enter your Gmail username here WITH OUT @gmail.com.( OR @domain)
export TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_USERNAME=""
# Google password. Recomenned to use application specific password (https://accounts.google.com/b/0/IssuedAuthSubTokens) Leave this empty to get password from OS X keychain.
# For OSX users : MAKE SURE that you add a key to the keychain in the format as follows
# Keychain Item name : http://<value-you-fill-in-server-variable-below>
# Account name : <username-below>@<server-below>
# Password : Your password ( Once again, try to use 2 step-verification and application-specific password)
# See http://support.google.com/accounts/bin/answer.py?hl=en&answer=185833 for more info.
export TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_PASSWORD=""
# Domain name that will complete your email. For normal GMail users it probably is "gmail.com but can be "foo.tld" for Google Apps users.
export TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_SERVER="${TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_SERVER_DEFAULT}"
# How often in minutes to check for new mails.
export TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_INTERVAL="${TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_INTERVAL_DEFAULT}"

## Maildir
# Path to the maildir to check.
export TMUX_POWERLINE_SEG_MAILCOUNT_MAILDIR_INBOX="${TMUX_POWERLINE_SEG_MAILCOUNT_MAILDIR_INBOX_DEFAULT}"

## mbox
# Path to the mbox to check.
export TMUX_POWERLINE_SEG_MAILCOUNT_MBOX_INBOX="${TMUX_POWERLINE_SEG_MAILCOUNT_MBOX_INBOX_DEFAULT}"
EORC
	echo "${rccontents}"
}

__process_settings() {
	if [ -z "$TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_SERVER" ]; then
		export TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_SERVER="${TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_SERVER_DEFAULT}"
	fi
	if [ -z "$TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_INTERVAL" ]; then
		export TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_INTERVAL="${TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_INTERVAL_DEFAULT}"
	fi

	eval TMUX_POWERLINE_SEG_MAILCOUNT_MBOX_INBOX="$TMUX_POWERLINE_SEG_MAILCOUNT_MBOX_INBOX"
	if [ -z "$TMUX_POWERLINE_SEG_MAILCOUNT_MAILDIR_INBOX" ]; then
		export TMUX_POWERLINE_SEG_MAILCOUNT_MAILDIR_INBOX="${TMUX_POWERLINE_SEG_MAILCOUNT_MAILDIR_INBOX_DEFAULT}"
	fi

	eval TMUX_POWERLINE_SEG_MAILCOUNT_MAILDIR_INBOX="$TMUX_POWERLINE_SEG_MAILCOUNT_MAILDIR_INBOX"
	if [ -z "${TMUX_POWERLINE_SEG_MAILCOUNT_MBOX_INBOX}" ]; then
		export TMUX_POWERLINE_SEG_MAILCOUNT_MBOX_INBOX="${TMUX_POWERLINE_SEG_MAILCOUNT_MBOX_INBOX_DEFAULT}"
	fi
}

run_segment() {
	__process_settings

	if [ -z "$TMUX_POWERLINE_SEG_MAILCOUNT_MAILBOX_TYPE" ]; then
		return 2
	fi

	local count
	case "$TMUX_POWERLINE_SEG_MAILCOUNT_MAILBOX_TYPE" in
		"apple_mail")  count=$(__count_apple_mail) ;;
		"gmail")  count=$(__count_gmail) ;;
		"maildir")  count=$(__count_maildir) ;;
		"mbox")  count=$(__count_mbox) ;;
		*)
			echo "Unknown mailbox type [${TMUX_POWERLINE_SEG_MAILCOUNT_MAILBOX_TYPE}]";
			return 1
	esac
	local exitcode="$?"
	if [ "$exitcode" -ne 0 ]; then
		return exitcode
	fi


	if [[ -n "$count"  && "$count" -gt 0 ]]; then
		echo "✉ ${count}"
	fi

	return 0
}


__count_apple_mail() {
  if [[ $(ps x | grep Mail\[\[:space:\]\]) ]]; then
    count=$(${TMUX_POWERLINE_DIR_SEGMENTS}/mailcount_apple_mail.script)
  else
    count=0
  fi
	echo "$count"
}

__count_gmail() {
	local tmp_file="${TMUX_POWERLINE_DIR_TEMPORARY}/gmail_count.txt"
	local override_passget="false"	# When true a force reloaded will be done.

	# Create the cache file if it doesn't exist.
	if [ ! -f $tmp_file ]; then
		touch $tmp_file
		override_passget=true
	fi

	# Refresh mail count if the tempfile is older than $interval minutes.
	let interval=60*$TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_INTERVAL
	if shell_is_osx; then
		last_update=$(stat -f "%m" ${tmp_file})
	elif shell_is_linux; then
		last_update=$(stat -c "%Y" ${tmp_file})
	fi
	if [ "$(( $(date +"%s") - ${last_update} ))" -gt "$interval" ] || [ "$override_passget" == true ]; then
		if [ -z "$TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_PASSWORD" ]; then # Get password from keychain if it isn't already set.
			if shell_is_osx; then
				__mac_keychain_get_pass "${TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_USERNAME}@${TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_SERVER}" "$TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_SERVER"
			else
				echo "Implement your own sexy password fetching mechanism here."
				return 1
			fi
		fi

		# Check for wget before proceeding.
		which wget 2>&1 > /dev/null
		if [ $? -ne 0 ]; then
			echo "This script requires wget." 1>&2
			return 1
		fi

		mail=$(wget -q -O - https://mail.google.com/a/${TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_SERVER}/feed/atom --http-user="${TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_USERNAME}@${TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_SERVER}" --http-password="${TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_PASSWORD}" --no-check-certificate | grep fullcount | sed 's/<[^0-9]*>//g')

		if [ "$mail" != "" ]; then
			echo $mail > $tmp_file
		else
			return 1
		fi
	fi

	# echo "$(( $(date +"%s") - $(stat -f %m $tmp_file) ))"
	count=$(cat $tmp_file)
	echo "$count"
	return 0;
} 

__count_maildir() {
	if [ ! -d "$TMUX_POWERLINE_SEG_MAILCOUNT_MAILDIR_INBOX" ]; then
		return 1
	fi

	count=$(ls "$TMUX_POWERLINE_SEG_MAILCOUNT_MAILDIR_INBOX" | wc -l)

	# Fix for mac, otherwise whitespace is left in output
	if shell_is_osx; then
		count=$(echo "$count" | sed -e "s/^[ \t]*//")
	fi

	echo "$count"
	return 0;
}

__count_mbox() {
	if [ ! -f "${TMUX_POWERLINE_SEG_MAILCOUNT_MBOX_INBOX}" ]; then
		return 1
	fi

	# This matches the From_ line (see man 5 mbox) e.g.
	# From noreply@github.com  Sun Dec	2 03:52:25 2012
	# See https://github.com/erikw/tmux-powerline/pull/91#issuecomment-10926053 for discussion.
	nbr_new=$(grep -c '^From [^[:space:]]\+  ... ... .. ..:..:.. ....$' ${TMUX_POWERLINE_SEG_MAILCOUNT_MBOX_INBOX})

	if [ "${nbr_new}" -gt "0" ]; then
		echo "✉ ${nbr_new}"
	fi

	return 0;
}

__mac_keychain_get_pass() {
	result=$(security 2>&1 > /dev/null find-internet-password -ga $1 -s $2)
	if [ $? -eq 0 ]; then
		TMUX_POWERLINE_SEG_MAILCOUNT_GMAIL_PASSWORD=$(echo $result | sed -e 's/password: \"\(.*\)\"/\1/g')
		return 0
	fi
	return 1
}
