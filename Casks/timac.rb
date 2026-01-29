# Homebrew Cask for Timac
#
# To create your own tap:
# 1. Create a new GitHub repo named "homebrew-tap" 
# 2. Add this file as Casks/timac.rb
# 3. Update the URL and SHA256 after each release
#
# Users can then install with:
#   brew tap vigeng/tap
#   brew install --cask timac

cask "timac" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_OF_DMG"

  url "https://github.com/vigeng/Timac/releases/download/v#{version}/Timac.dmg"
  name "Timac"
  desc "Menu bar app for tracking time spent on applications"
  homepage "https://github.com/vigeng/Timac"

  depends_on macos: ">= :ventura"

  app "Timac.app"

  zap trash: [
    "~/Library/Application Support/Timac",
    "~/Library/Preferences/com.timac.Timac.plist",
    "~/Library/Saved Application State/com.timac.Timac.savedState",
  ]
end
