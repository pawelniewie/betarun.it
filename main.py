#!/usr/bin/env python
#
# Copyright 2007 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
import webapp2
import os
import feedparser

appcast = os.path.join(os.path.dirname(__file__), 'appcast.xml')

class UpdatesHandler(webapp2.RequestHandler):
	def get(self):
		self.response.headers['Content-Type'] = 'application/rss+xml'
		self.response.write(file(appcast,'rb').read())

class DownloadHandler(webapp2.RequestHandler):
	def get(self):
		feed = feedparser.parse(appcast)
		return self.redirect(str(feed.entries[0].enclosures[0].href))

app = webapp2.WSGIApplication([
	webapp2.Route('/', handler = webapp2.RedirectHandler, defaults = {'_uri' : 'http://pawelniewiadomski.com/queued'}),
	('/download', DownloadHandler),
	('/updates.xml', UpdatesHandler)
], debug=True)
