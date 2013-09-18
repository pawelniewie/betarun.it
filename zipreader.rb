$: << "./vendor/install/ruby/2.0.0/gems/rubyzip-1.0.0/lib/"
$: << "./vendor/install/ruby/2.0.0/gems/CFPropertyList-2.2.1/lib/"

require "zip"
require "cfpropertylist"

module InfoFile
	def InfoFile.get_info_from_zip(file)
		Zip::File.open(file) do |zip|
			zip.each do |entry|
				if (not entry.directory?)
					path = entry.name.split(/\//)
					if (path.size == 3 and path[0].downcase.end_with?(".app") and path[1].casecmp("Contents") == 0  and path[2].casecmp("Info.plist") == 0)
						entry.get_input_stream do |stream|
							plist = CFPropertyList::List.new(:data => stream.read)
							return CFPropertyList.native_types(plist.value)
						end
					end
				end
			end
		end
		return nil
	end
end

# {"CFBundleName"=>"Queued", "DTXcode"=>"0500", "DTSDKName"=>"macosx10.9",
# "NSHumanReadableCopyright"=>"Copyright © 2013 Pawel Niewiadomski. All rights reserved.",
# "SUShowReleaseNotes"=>true, "SUEnableAutomaticChecks"=>true, "FullVersion"=>"0.7-dirty", "DTSDKBuild"=>"13A476n",
# "CFBundleDevelopmentRegion"=>"en", "CFBundleVersion"=>"74", "BuildMachineOSBuild"=>"13A538g",
# "NSPrincipalClass"=>"NSApplication", "NSMainNibFile"=>"MainMenu", "CFBundlePackageType"=>"APPL",
# "CFBundleIconFile"=>"AppIcon", "CFBundleShortVersionString"=>"0.7", "SUEnableSystemProfiling"=>true,
# "SUFeedURL"=>"http://queuedupdates.appspot.com/updates.xml", "CFBundleInfoDictionaryVersion"=>"6.0",
# "CFBundleExecutable"=>"Queued", "DTCompiler"=>"com.apple.compilers.llvm.clang.1_0",
# "CFBundleIdentifier"=>"com.pawelniewiadomski.Queued", "LSApplicationCategoryType"=>"public.app-category.social-networking",
# "DTPlatformVersion"=>"GM", "DTXcodeBuild"=>"5A11314m", "CFBundleSignature"=>"????", "LSMinimumSystemVersion"=>"10.8",
# "DTPlatformBuild"=>"5A11314m", "LSUIElement"=>true}
if __FILE__ == $0
	puts InfoFile::get_info_from_zip("/Users/pawel/Development/Queued/Updates/binaries/Queued-0.7.zip")
end