#!/bin/bash
input="Classes/WebRTCUI/Resources/MMCalls.storyboard"
output="Classes/WebRTCUI/Resources/MMCalls_SPM.storyboard"

generate () {
  chmod 666 "${output}"
  cp "$input" "$output"
  sed -i '' 's/customModule=\"MobileMessaging\"/customModule=\"WebRTCUI\"/g' $output
  chmod 444 "${output}"
}

generate