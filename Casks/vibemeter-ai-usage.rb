cask "vibemeter-ai-usage" do
  version "0.1.0"
  sha256 "af8423bc045c74f5ecc73b0f060992b031e2450b2899a1d034c508a4bf7a11be"

  url "https://github.com/ivansandev/homebrew-vibemeter/releases/download/v#{version}/VibeMeter-#{version}.zip"
  name "VibeMeter"
  desc "Claude and Codex usage in the macOS menu bar"
  homepage "https://github.com/ivansandev/homebrew-vibemeter"

  depends_on macos: :sequoia

  app "VibeMeter.app"

  zap trash: [
    "~/Library/Application Support/VibeMeter",
    "~/Library/Preferences/dev.ivansandev.vibemeter.plist",
  ]
end
