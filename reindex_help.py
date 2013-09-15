#!/usr/bin/env python
# -*- coding: UTF-8 -*-

"""
This script (re)generates the help index for every locale.
"""

import os
import sys
import subprocess

PROJECT_PATH = os.path.dirname(__file__);
HELPBOOK_PATH = os.path.join(PROJECT_PATH, "Resources/Boxer.help")
STANDALONE_HELPBOOK_PATH = os.path.join(PROJECT_PATH, "Standalone/Resources/Help.help")
HELP_INDEX_NAME = "search.helpindex"

def locales_in_path(path):
	locales = []
	for name in os.listdir(path):
		basename, ext = os.path.splitext(name)
		if ext.lower() == ".lproj": locales.append(name)
		
	return locales

def reindex_helpbook(helpbook_path):
	"""
	Reindexes all locales within the helpbook at the specified path.
	"""
	
	helpbook_resource_path = os.path.join(helpbook_path, "Contents", "Resources")
	
	for locale in locales_in_path(helpbook_resource_path):
		print u" -- Reindexing locale %s..." % locale
		locale_path = os.path.join(helpbook_resource_path, locale)
		index_path = os.path.join(locale_path, HELP_INDEX_NAME)
		subprocess.call(["hiutil", "-C", "-a", "-s", "en", "-vv", "-m", "2", "-f", index_path, locale_path])
	# Touch the path so that XCode will see that it has changed when building.
	os.utime(helpbook_path, None)

def kill_helpd():
	"""
	Kills the helpd process to reset its help cache.
	"""
	subprocess.call(["killall", "helpd"])
			
if __name__ == "__main__":
	if len(sys.argv) > 1:
		helpbook_paths = sys.argv[1:]
	else:
		helpbook_paths = [HELPBOOK_PATH, STANDALONE_HELPBOOK_PATH]

	for helpbook_path in helpbook_paths:
		print u"Reindexing helpbook %s..." % helpbook_path
		reindex_helpbook(helpbook_path)
		
	print u"Restarting helpd process..."
	kill_helpd()
	