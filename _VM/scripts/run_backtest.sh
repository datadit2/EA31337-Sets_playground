#!/usr/bin/env bash
#set -x
VDIR="/vagrant"
OUT="/opt"
CONF="mt4-tester.ini"
TPL="$VDIR/conf/$CONF"
FIND_EXCLUDES="-path *dosdevices* -prune -o"

# Check dependencies.
type realpath || { echo "The realpath is required."; exit 1; }

# Define functions.

clean_files() {
  find -L "$OUT" $FIND_EXCLUDES '(' -name "*.log" -or -name '*.dat' -or -name '*.htm' ')' -delete # Remove old log, dat and htm files.
}

check_logs() {
  find -L "$OUT" $FIND_EXCLUDES -name "*.log" -exec tail "{}" ';'
}

configure_wine() {
# Configure wine.
  export WINEDLLOVERRIDES="mscoree,mshtml=" # Disable gecko in wine.
  export DISPLAY=:0.0 # Select screen 0.
  #export WINEDEBUG=warn+all # For debugging, try: WINEDEBUG=trace+all
}

on_success() {
  echo "Test succeded."
  #echo 'Check logs'
  #check_logs
  echo 'FIND Report*'
  find -L "$TERMINAL_DIR" $FIND_EXCLUDES -name "Report*.htm" -print
  echo 'html2text'
  html2text "$(find -L "$TERMINAL_DIR" $FIND_EXCLUDES -name "Report*.htm")"
  echo 'DEST & find'
  [ "$DEST" ] && find -L "$TERMINAL_DIR" $FIND_EXCLUDES -name "*Report*" -and -not -path "*templates/*" -execdir cp -v "{}" "$DEST" ';'
}

on_failure() {
  echo "Test failed."
  check_logs
}

# Check if terminal is present.
[ "$(find -L "$OUT" $FIND_EXCLUDES -name terminal.exe -print -quit)" ] || $VDIR/scripts/dl_mt4.sh
TERMINAL_EXE="$(find -L "$OUT" $FIND_EXCLUDES -name terminal.exe -print -quit)"
TERMINAL_DIR="$(dirname "$TERMINAL_EXE")"
TERMINAL_INI="$TERMINAL_DIR/config/$CONF"

# Copy the configuration file, so platform can find -L it.
cp -v "$TPL" "$TERMINAL_INI"

# Parse the arguments.
while getopts r:f:n:p:d:y:s:b:D: opts; do
  case ${opts} in
    r) # The name of the test report file. A relative path can be specified
      if [ -s "$(dirname "${OPTARG}")" ]; then # If base folder exists,
        REPORT="$(realpath --relative-to="${TERMINAL_DIR}" "${OPTARG}")" # ... treat as relative path
      else
        REPORT="$(basename "${OPTARG}")" # ... otherwise, it's a filename.
      fi
      [ "$REPORT" ]  && ex -s +"%s#^TestReport=\zs.\+\$#$REPORT#" -cwq "$TERMINAL_INI"
      echo "REPORT = $REPORT"
      ;;

    f) # The set file to run the test.
      SETFILE=${OPTARG}
      echo "SETFILE = $SETFILE"
      [ -s "$SETFILE" ] && cp -v "$SETFILE" "$TERMINAL_DIR/tester"
      [ "$SETFILE" ]    && ex -s +"%s/^TestExpertParameters=\zs.\+$/$SETFILE/" -cwq "$TERMINAL_INI"
      ;;

    n) # EA name.
      EA_NAME=${OPTARG}
      echo "EA_NAME = $EA_NAME"
      EA_PATH="$(find -L "$VDIR" '(' $FIND_EXCLUDES -name "*$EA_NAME*.ex4" -or $FIND_EXCLUDES -name "*$EA_NAME*.ex5" ')' -print -quit)"
      [ -s "$EA_PATH" ]  && { cp -v "$EA_PATH" "$TERMINAL_DIR/MQL4/Experts"; EA_NAME="$(basename "$EA_PATH")"; }
      [ "$EA_NAME" ]     && ex -s +"%s/^TestExpert=\zs.\+$/$EA_NAME/" -cwq "$TERMINAL_INI"
      ;;

    p) # Symbol pair to test.
      SYMBOL=${OPTARG}
      echo "SYMBOL = $SYMBOL"
      [ "$SYMBOL" ]      && ex -s +"%s/^TestSymbol=\zs.\+$/$SYMBOL/" -cwq "$TERMINAL_INI"
      ;;

    d) # Deposit amount to test.
      DEPOSIT="$5"
      echo "DEPOSIT = $DEPOSIT"
      # @todo: Set the right deposit for the test.
      ;;

    y) # Year to test.
      YEAR=${OPTARG}
      echo "YEAR = $YEAR"
      FROM="$YEAR.01.01"
      TO="$YEAR.01.02"
      [ "$FROM" ]       && ex -s +"%s/^TestFromDate=\zs.\+$/$FROM/" -cwq "$TERMINAL_INI"
      [ "$TO" ] 	      && ex -s +"%s/^TestToDate=\zs.\+$/$TO/" -cwq "$TERMINAL_INI"
      ;;

    s) # Spread to test.
      SPREAD=${OPTARG}
      echo "SPREAD = $SPREAD"
      # @todo: Set the right spread for the test.
      ;;

    b) # Backtest data to test.
      BT_SOURCE=${OPTARG}
      echo "BT_SOURCE = $BT_SOURCE"
      # @todo: Place the right backtest data into the right place and change the profile name.
      [ "$(find -L "$OUT" $FIND_EXCLUDES -name '*.fxt')" ] || $VDIR/scripts/dl_bt_data.sh # Download backtest files if not present.
      ;;

    D) # Destination directory to save test results.
      DEST=${OPTARG}
      echo "DEST = $DEST"
      ;;

  esac
done

# Prepare before test run.
clean_files
configure_wine

# Run the test in the platform.
grep ^TestReport "$TERMINAL_DIR/config/$CONF"
echo 'WINE'
time wine "$TERMINAL_EXE" "config/$CONF" &> /dev/null && on_success || on_failure
