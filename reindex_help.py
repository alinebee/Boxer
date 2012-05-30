#!/usr/bin/env python
# -*- coding: UTF-8 -*-

"""
This script (re)generates the help index for every locale.
"""

import os
import subprocess

RESOURCE_PATH = os.path.join(os.path.dirname(__file__), "Resources")
HELP_FOLDER_NAME = "BoxerHelp"
HELP_INDEX_NAME = "BoxerHelp.helpindex"

def locales_in_path(path):
	locales = []
	for name in os.listdir(path):
		basename, ext = os.path.splitext(name)
		if ext.lower() == ".lproj": locales.append(name)
		
	return locales

def reindex_help_for_locale(locale):
	"""
	Reindexes the help folder for the specified locale.
	"""
	locale_path = os.path.join(RESOURCE_PATH, locale)
	help_path = os.path.join(RESOURCE_PATH, locale, HELP_FOLDER_NAME)
	index_path = os.path.join(help_path, HELP_INDEX_NAME)
	
	subprocess.call(["hiutil", "-C", "-a", "-s", "en", "-m", "2", "-f", index_path, help_path])
	# Touch the path so that XCode will see that it has changed when building.
	os.utime(help_path, None)

def kill_helpd():
	"""
	Kills the helpd process to reset its help cache.
	"""
	subprocess.call(["killall", "helpd"])
			
if __name__ == "__main__":
	for locale in locales_in_path(RESOURCE_PATH):
		reindex_help_for_locale(locale)
		
	kill_helpd()
	