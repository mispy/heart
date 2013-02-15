task :default => [:compile]

task :compile do
  `coffee -c *.coffee; cat emile.min.js heart.js > .tmp.combined.js; slimit .tmp.combined.js > combined.js`
  puts File.read('combined.js')
  puts "\nhttp://moxleystratton.com/javascript/bookmarklet-compiler"
  puts "Paste code at this link to create bookmarklet."
end
