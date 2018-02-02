require 'net/http'
PAGE    = URI "https://rubyinstaller.org/downloads/archives/"
DIR     = File.dirname(File.expand_path(__FILE__)).tr("/", "\\")
ARIA2C  = File.join(DIR, "libexec/aria2c.exe").tr("/", "\\")
A7ZIP   = File.join(DIR, "libexec/7za.exe").tr("/", "\\")
PACKAGE = File.join(DIR, "ruby/package").tr("/", "\\")

def require_gem(a)
begin
    gem a
rescue Exception
    system "gem install #{a}"
    gem a
end
require a
end

require_gem 'thor'


class LVM < Thor
    private 
    def versionlist
        begin
            f = Marshal.load(IO.binread("list"))
        rescue
            require_gem 'nokogiri'
            v = Net::HTTP.get(URI(PAGE))
            page = Nokogiri::HTML(v)
            f = page.css("a").select{|x| x["href"] && x["href"][/\.7z$/]}.map{|x| x["href"]}
            IO.binwrite "list", Marshal.dump(f)
            f
        end
        
    end

    def download(href)
        file = File.basename(href)
        if system("#{ARIA2C} #{href} -j100 -s20 -d #{PACKAGE} -o #{file} --conditional-get --console-log-level=error 1>&2")
            File.join(PACKAGE, file)
        else
            nil
        end
    end

    def unzip(file, output)
        output = output.tr("/", "\\")
        file = file.tr("/", "\\")
        system "#{A7ZIP} x -aos -o#{output} #{file} 1>&2"
    end

    public
    desc "list", "List available versions"
    def list
        puts versionlist.map{|x| x["href"][/\d+\.\d+\.\d+/]}.uniq.join("\n")
    end

    desc "use [VERSION]", "Get and use certain version of ruby"
    def use(version)
        href = versionlist.find{|x| x[version]}
        if !href
            STDERR.puts "can't get #{version}"
            exit
        end
        if (filename = download(href))
            unzip filename, File.join(DIR, "ruby/ruby/")
            path = ENV['path']
            outpath = File.join(File.join(File.join(DIR, "ruby/ruby"), File.basename(filename, ".*")), "/bin").tr("/", "\\")
            path[outpath] = "" if path[outpath]
            path[";;"]=";" if path[";;"]
            path = "#{outpath};#{path}"
            puts "set path=#{path}"
            puts "REM @FOR /f \"tokens=*\" %i IN ('ruby lvm.rb use #{version}') DO @%i"
        end
    end
    start ARGV
end