require 'yaml'

helm = ARGV[0]
values = YAML.load_file(File.join(helm, 'values.yaml'))

images = {}
Dir.glob(File.join(helm, "templates", "*.yaml")).each do |file|
  File.open(file).each do |line|
    /^\s+image:.*kube.organization ?}}\/(.*?)"/.match(line) do |match|
      images[match[1]] = true
    end
    # config variables with the imagename option may point to a bundled image
    /^\s+value:.*kube.organization "\/" .Values.env.(\S+)/.match(line) do |match|
      image = values['env'][match[1]]
      images[image] = true unless image.empty? || image.include?("/")
    end
  end
end

File.open(File.join(helm, "values.yaml")).each do |line|
  ["DOWNLOADER","EXECUTOR","UPLOADER"].each do |image|
    /^\s+EIRINI_#{image}_IMAGE: ["'].+\/([^\/]*)["']$/.match(line) do |match|
      images[match[1]] = true
    end
  end
end

File.open(File.join(helm, "imagelist.txt"), "w") do |file|
  file.puts(images.keys.sort)
end
