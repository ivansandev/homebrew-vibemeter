cask "vibemeter" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/ivansandev/homebrew-vibemeter/releases/download/v#{version}/VibeMeter-#{version}.zip"
  name "VibeMeter"
  desc "Claude and Codex usage in the macOS menu bar"
  homepage "https://github.com/ivansandev/homebrew-vibemeter"

  depends_on macos: ">= :sequoia"

  app "VibeMeter.app"

  zap trash: [
    "~/Library/Application Support/VibeMeter",
    "~/Library/Preferences/dev.ivansandev.vibemeter.plist",
  ]
end
