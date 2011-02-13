/*
This dynamically rewrites certain link types to use Applescript components instead,
for special features of the Help Viewer.
*/

if (navigator.userAgent.indexOf("Help Viewer") > -1)
{
	
	var baseScriptURL = 'x-help-script://net.washboardabs.boxer.help/../shared/scripts/';
	
	var emailLinks = $('a[rel=email]');
	var quicklookLinks = $('a[rel=quicklook]');
	
	emailLinks.each(function() {
		this.href = baseScriptURL + 'openurl.scpt?' + this.href;
	});
	
	
	quicklookLinks.each(function() {
		this.href = baseScriptURL + 'quicklookurl.scpt?' + this.href;
	});
}