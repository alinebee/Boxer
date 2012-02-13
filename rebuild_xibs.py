#!/usr/bin/env python
# -*- coding: UTF-8 -*-

"""
This script (re)generates localized XIB files for each of Boxer's locales,
based on the original English XIBs and the localized .strings files for each XIB.
"""

import os
import subprocess

RESOURCE_PATH = os.path.join(os.path.dirname(__file__), "Resources")
DEFAULT_LOCALE = "English.lproj"

def locales_in_path(path):
	locales = []
	for name in os.listdir(path):
		basename, ext = os.path.splitext(name)
		if ext.lower() == ".lproj": locales.append(name)
		
	return locales

def xibs_in_path(path):
	xibs = []
	for name in os.listdir(path):
		basename, ext = os.path.splitext(name)
		if ext.lower() == ".xib": xibs.append(name)
			
	return xibs


def export_strings_for_locale(locale):
	"""
	Exports localizable .strings files for all XIBs in the specified locale.
	"""
	path = os.path.join(RESOURCE_PATH, locale)
	
	for name in xibs_in_path(path):
		basename, ext = os.path.splitext(name)
		
		xib_path = os.path.join(path, name)
		string_path = os.path.join(path, basename + ".strings")
		
		subprocess.call(["ibtool", "--export-strings-file", string_path, xib_path])


def build_xibs_for_locale(locale, source_locale=DEFAULT_LOCALE):
	"""
	Builds localized XIBs for the specified locale, by importing the .strings files
	for that locale into the XIBs from the source locale.
	"""
	dest_path = os.path.join(RESOURCE_PATH, locale)
	source_path = os.path.join(RESOURCE_PATH, source_locale)
	
	for name in xibs_in_path(source_path):
		basename, ext = os.path.splitext(name)
		
		source_xib_path = os.path.join(source_path, name)
		source_string_path = os.path.join(dest_path, basename + ".strings")
		dest_xib_path = os.path.join(dest_path, name)
		
		if os.path.exists(source_string_path):
			subprocess.call(["ibtool", "--import-strings-file", source_string_path, "--write", dest_xib_path, source_xib_path])
			
if __name__ == "__main__":
	# TODO: split these so that they work by arguments instead
	export_strings_for_locale(DEFAULT_LOCALE)
	
	for locale in locales_in_path(RESOURCE_PATH):
		#Skip the default locale
		if locale == DEFAULT_LOCALE: continue
		
		build_xibs_for_locale(locale)
	