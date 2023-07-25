#!/bin/bash
input="Classes/Core/Localization/en.lproj/MobileMessaging.strings"
output="Classes/Core/Utils/MMLoc.swift"


generate () {
  chmod 666 "${output}"
  echo "//" > $output
  echo "//  ${output##*/}" >> $output
  echo "//  ConversationsMobile" >> $output
  echo "//" >> $output
  echo "//  Created by localiseStrings.sh on $(date +%d/%m/%Y)." >> $output
  echo "//  Copyright © $(date +%Y) Infobip Ltd. All rights reserved." >> $output
  echo "//" >> $output
  echo >> $output
  echo "// This file was generated automatically by localiseString.sh script. You can update the variables in MMLoc by cleaning and building the MobileMessaging SDK project." >> $output
  echo >> $output
  echo "// swiftlint:disable identifier_name" >> $output
  echo "// swiftlint:disable line_length" >> $output
  echo "// swiftlint:disable file_length" >> $output
  echo "// swiftlint:disable type_body_length" >> $output
#  echo "// swiftlint:disable type_name" >> $output
  echo >> $output
  echo "public enum MMLoc {" >> $output
  while IFS= read -r line
  do
    #gen_const "$line"
    local curKey=$(gen_const "$line")
    local curValue=$(gen_value "$line")
    local camelKey=$(snakeToCamel "$curKey")
    if [ ! -z "$curKey" ]
    then
      echo "    public static var \`${camelKey}\`: String { return  MMLocalization.localizedString(forKey: \"mm_${curKey}\", defaultString: \"${curValue}\") }" >> $output
    fi
  done < "$input"
  echo "}" >> $output
  chmod 444 "${output}"
}

gen_const () {
  local fullString="$1"
  local quotedKey="${fullString%=*}"
  local keyWithPrefix="${quotedKey//\"/}"
  local key="${keyWithPrefix#mm_}"
  echo "${key//\ /}"
}

gen_value () {
  local fullString="$1"
  local cutSemicolonString="${fullString%;*}"
  local quotedValue="${cutSemicolonString##*=}"
  local value="${quotedValue//\"/}"
  echo "${value}" | xargs
}

snakeToCamel () {
  local snakeKey="$1"
  echo "${snakeKey}" | perl -nE 'say lcfirst join "", map {ucfirst lc} split /[^[:alnum:]]+/'
  local step1= $key 
}

outDate=$(stat -f "%m" "$output")
inDate=$(stat -f "%m" "$input")

if ! test -f "$output"
then
  generate
fi

if [ $((inDate)) -gt $((outDate)) ]
then
  echo "$output is outdated. last changes in: $inDate, out: $outDate"
  generate
else
  echo "$output is not outdated. last changes in: $inDate, out: $outDate"
fi
