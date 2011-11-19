package Nogag::Formatter::tDiary;

use v5.14;
use utf8;
use strict;
use warnings;

sub format {
	my ($class, $string) = @_;
	$string =~ s{<%=([\s\S]+?)%>}{
		$class->format_plugin($1);
	}eg;
	'<p>' . join('</p><p>', split /\n/, $string) . '</p>';
}

sub format_plugin {
	my ($class, $ruby) = @_;
	my $ret  = '';
	$ruby =~ s/^\s*|\s*$//g;
	
	given ($ruby) {
		when (/bq <<(\w+)(?:, ['"](?<title>[^'"]+)["'])?(?:, ['"](?<cite>[^'"]+)["'])?\n(?<quote>[\s\S]*?)\n\1/) {
			if ($+{cite}) {
				$ret = sprintf('<blockquote title="%s" cite="%s"><p>%s</p></blockquote>', $+{title}, $+{cite}, $+{quote});
			} elsif ($+{title}) {
				$ret = sprintf('<blockquote title="%s"><p>%s</p></blockquote>', $+{title}, $+{quote});
			} else {
				$ret = sprintf('<blockquote><p>%s</p></blockquote>', $+{quote});
			}
		}

		when (/a (['"])(?:(?<title>[^|]+)\|)?(?<url>.+?)\1/) {
			$ret = sprintf('<a href="%s">%s</a>', $+{url}, $+{title} || $+{url});
		}

		when (/(?<name>ul|ol) (['"])(?<string>[^'"]+?)\2/) {
			$ret .= '<' . $+{name} . '>';
			$ret .= '<li>' . join('</li><li>', split(/\n/, $+{string})) . '</li>';
			$ret .= '</' . $+{name} . '>';
		}

		when (/(?<name>ul|ol) <<(\w+)\n(?<string>[\s\S]*?)\n\2/) {
			$ret = '<ul><li>' . join('</li><li>', split(/\n/, $+{string})) . '</li></ul>';
		}

		when (/fn (['"])(?<string>[^'"]+?)\1/) {
			$ret = sprintf('<span title="%s">*</span>', $+{string});
		}

		when (/my ['"](?<path>[^'"]+)['"], ['"](?<label>[^'"]+)['"]/) {
			my ($year, $month, $day, $p) = ($+{path} =~ /^(\d\d\d\d)(\d\d)(\d\d)#p(\d+)$/) or die $+{path};
			my $path = sprintf("%04d/%02d/%02d/%d", $year, $month, $day, $p);
			$ret = sprintf('<a href="%s">%s</a>', $path, $+{label});
		}

		default {
			die $ruby;
		}
	}

	$ret;
}

1;
