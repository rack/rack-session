
def external
	clone_and_test("sinatra")
end

private

def clone_and_test(name, remote, test_command)
	require 'fileutils'
	
	path = "external/#{name}"
	FileUtils.rm_rf path
	FileUtils.mkdir_p path
	
	system("git", "clone", remote, path)
	
	# I tried using `bundle config --local local.async ../` but it simply doesn't work.
	# system("bundle", "config", "--local", "local.async", __dir__, chdir: path)
	
	gemfile_paths = ["#{path}/Gemfile", "#{path}/gems.rb"]
	gemfile_path = gemfile_paths.find{|path| File.exist?(path)}
	
	File.open(gemfile_path, "a") do |file| 
		file.puts('gem "rack-session", path: "../../"')
	end
	
	system("bundle", "install", chdir: path)
	system(test_command, chdir: path) or abort("Tests failed!")
end
