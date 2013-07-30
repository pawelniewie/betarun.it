If you're like me you want to have auto updating app right from the start. It's one of those things that you can do to make the customers see what's going on in the project without actually thinking about it.

For Mac there's a great (and free) software called [Sparkle](http://sparkle.andymatuschak.org) that you can use to built-in this functionality in your app. That's one part of the puzzle.

The other part is some place where you actually store your updates and Google App Engine can be a good place for it - it's free (at least for small apps that don't generate a lot of traffic).

All you need to do is tell Sparkle where to look for updates and place the file on the server (with binaries).

Sparkle has already [a lot of documentation](https://github.com/andymatuschak/Sparkle/wiki) about it so I'm not going to repeat it here. The one thing to mention is that you probably want to grab the newest Sparkle from repository and compile it on your own.

If you do this you will not have to maintain keys and sign binaries on your own, because you already sign them with your Mac App Store developer certificate and the newest Sparkle can understand that (it will allow to upgrade your app with a binary signed by the same key).

To speed up things a bit I already prepared for you [a sample Google App Engine app](https://github.com/pawelniewie/sparkle-appcast-server) that you can base your app cast on.

You need to update app.yaml and update the name, change appcast.xml to list your updates (the one I use here is for [Queued](http://pawelniewiadomski.com/queued)).

All requests will be handled by main.py which is great if you want to store additional info about clients (Sparkle can upload some info about os, machine, etc.) but also give you a handy url that you can place on your site to link to the newest binary (it will read it automatically from the appcast.xml).

You still need to upload everything with appcfg.py (Google App Engine's command line tool), maybe some day in the future I'll add uploading via web. That would be handy.

[Download it now and make an app cast for your app in minutes!](https://github.com/pawelniewie/sparkle-appcast-server)