jQuery(document).ready(function() {
	
    // Rewrite the email address so bots can't find it without activating js
    // currently not active since footer is not shown, but might be useful later
	$(function() {
		$(".rplcAt").replaceWith("@");
		$(".obEmail").each(function() {
			$(this).attr("href", "mailto:" + $(this).text());
		});
	});

	$('odd_background:odd').css({
		backgroundColor : '#343434'
	});
    
});



function delete_corpus(path) {
    $("#dialog-confirm-delete").data("path", path).dialog("open");
    return false;
};

function delete_file(path) {
    $("#dialog-confirm-delete").data("path", '/delete/' + path).dialog("open");
    return false;
};


function download_file(path) {
    window.location = '/download/' + path;
    return false;
};

function import_resource(path) {
    window.location = '/import/' + path;
    return false;
};


// Reloads the content of the 'Raw' and 'Content' tab in the right tab panel
// with the current revision selection and line 'from'-'to' numbers
function cat_from_to(form) {
    // Get the values form the form and create a link to reload the content div
	var from = form.from.value;
	var to   = form.to.value;
	var rev  = form.rev.value;
	var link = form.link.value;
	var cat_link = link.concat('?from=', from, '&to=', to, '&rev=', rev);
	
	$(".raw_content").parent().parent().load(cat_link);
	return false;
}

$(function() {
	
	// #########################################################################
	// Delete Confirmation Dialog
	// #########################################################################
	$("#dialog-confirm-delete").dialog({
		resizable : true,
		height : 170,
		width : 300,
		modal : true,
		autoOpen : false,
		buttons : {
			"Delete Resource" : function() {
				$(this).dialog("close");
				window.location = $(this).data('path');
				return false;
			},
			Cancel : function() {
				$(this).dialog("close");
				return false;
			}
		}
	});


	// #########################################################################
	// Help Dialogs
	// #########################################################################
	$("div[id^='dialog_help_']").dialog({
		resizable : true,
		height : 250,
		width : 350,
		modal : false,
		autoOpen : false,
	});


	
	// #########################################################################
	// Tabs for the File Cat Template
	// #########################################################################
	$("#tabs").tabs(
		{
			ajaxOptions : {
				error : function(xhr, status, index, anchor) {
					$(anchor.hash).html("Couldn't load this tab.");
				}
	
			}
		}
	);
	
	$(function() {
		$( "#tabs_right" ).tabs();
	});

});

//#
//# This file is part of LetsMT! Resource Repository.
//#
//# LetsMT! Resource Repository is free software: you can redistribute it
//# and/or modify it under the terms of the GNU General Public License as
//# published by the Free Software Foundation, either version 3 of the
//# License, or (at your option) any later version.
//#
//# LetsMT! Resource Repository is distributed in the hope that it will be
//# useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
//# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//# General Public License for more details.
//#
//# You should have received a copy of the GNU General Public License
//# along with LetsMT! Resource Repository.  If not, see
//# <http://www.gnu.org/licenses/>.
//#