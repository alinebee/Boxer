/*
This dynamically rewrites certain link types to use Applescript components instead,
for special features of the Help Viewer.
*/

if (navigator.userAgent.indexOf("Help Viewer") > -1)
{
	
	var baseScriptURL = 'help:runscript=BoxerHelp/shared/scripts/';
	
	var emailLinks = $('a[rel=email]');
	var quicklookLinks = $('a[rel=quicklook]');
	
	emailLinks.each(function() {
		this.href = baseScriptURL + "openurl.scpt string='" + encodeURI(this.href) + "'";
	});
	
	
	quicklookLinks.each(function() {
		this.href = baseScriptURL + "quicklookurl.scpt string='" + encodeURI(this.href) + "'";
	});
}