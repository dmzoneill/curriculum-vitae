#!/usr/bin/perl

use strict;
use warnings 'all';
use feature 'say';

use File::Slurp;
use YAML qw(LoadFile);
use Data::Dumper qw(Dumper);

my $cv_details = $ENV{'cv_file'};
my $template = $ENV{'template_file'};
my $out_html = $ENV{'output_file'};

my $template_html = read_file($template);
my %cv_yaml = %{ LoadFile($cv_details) };

sub section_replace_scalars
{
  my ($section, $replacements) = @_;

  print ">> section_replace_scalars\n";
  print $section . "\n";
  print $replacements . "\n";
  print ref($replacements) . "\n";

  if ($section =~ /{list_item}/) {
    print "{list_item}\n";
    if (ref($replacements) eq "") {
      print "string replacement\n";
      print $replacements . "\n";
      $section =~ s/{list_item}/$replacements/sm;
      print $section . "\n";
    } else {
      print "list replacement\n";
      my $details = "";
      foreach my $k (keys %{$replacements}) {
        my $copy = $section;
        $copy =~ s/{list_item}/%{$replacements}{$k}/sm;
        $details .= $copy;
      }
      $section = $details;
    }
  } else {
    my (@matches) = ($section =~ m/\{(.*?)\}/g);
    foreach my $match (@matches) {
      my $val = %$replacements{$match};
      $section =~ s/\{$match\}/$val/smg;
    }
  }

  return $section;
}

sub references
{
  my ($match) = ($template_html =~ m/<references>(.*?)<\/references>/ms);

  my $replacement = "";
  foreach my $ref (@{$cv_yaml{"references"}}) {
    $replacement .= section_replace_scalars($match, $ref);
  }

  $template_html =~ s/\<references>(.*?)<\/references>/$replacement/sm;
}


sub pages
{
  for (my $count = 1; $count <= 2; $count++) {
    my $match = $template_html =~ m/<page$count>(.*?)<\/page$count>/ms;
    my $page = $cv_yaml{"pages"}[$count];
    my $jobs = $page->{"jobs"};
    my $replacement = "";

    foreach my $job ($jobs) {
      my $job_section = $match;
      my $role_match = $job_section =~ m/<roles>(.*?)<\/roles>/ms;
      my $roles_replacement = "";

      foreach my $role ($job->{"roles"}) {
        my $role_section = $role_match;
        my $details_match = $role_section =~ m/<details>(.*?)<\/details>/ms;
        my $details_replacement = "";

        foreach my $detail ($role->{"details"}) {
          my $detail_copy = section_replace_scalars($details_match, $detail);
          $details_replacement .= $detail_copy;
        }

        $role_section =~ s/<details>.*?<\/details>/$details_replacement/smg;
        $role_section = section_replace_scalars($role_section, $role);
        $roles_replacement .= $role_section;
      }

      $job_section =~ s/<roles>.*?<\/roles>/$roles_replacement/smg;
      $job_section = section_replace_scalars($job_section, $job);
      $replacement .= $job_section;
    }

    $template_html =~ s/<page$count>.*?<\/page$count>/$replacement/smg;
  }
}

sub roles
{
  $template_html =~ s/{current-role}/%cv_yaml{"roles"}[0]/sm;

  if($template_html =~ m/<previous-roles>(.*?)<\/previous-roles>/ms){
    my $rows = "";
    my $count = 0;
    my $html = $1;
    foreach my $entry (%cv_yaml{"roles"}) {
      if ($count == 0) {
        $count = $count + 1;
        next;
      }

      my $row = $html;
      $row = section_replace_scalars($row, $entry);
      $rows .= $row;
    }

    $template_html =~ s/<previous-roles>(.*?)<\/previous-roles>/$rows/sm;
  }
}

sub replace
{
  references();
  # pages();
  roles();

  foreach my $X (keys %cv_yaml) {
    if (ref($cv_yaml{$X}) eq "") {
      my $replacement = $cv_yaml{$X};
      
      if(index($replacement, "\n") > 0) {
        $replacement =~ s/\n/<br\/>/sm;
      }

      $template_html =~ s/\{$X\}/$replacement/smg;
    } elsif (ref($cv_yaml{$X}) eq "ARRAY") {
      
      if($template_html =~ m/<$X>(.*?)<\/$X>/gms) {

        print "---\n";
        print $X . "\n";
        print $1 . "\n";
        # print $cv_yaml{$X} . "\n";
        # print ref($cv_yaml{$X}) . "\n";
        # print "+++\n";
        # print $#match_instance;
        # print @match_instance;
        # print "###\n";


        my $list_replacement = "";
        foreach my $y (%cv_yaml{$X}) {
          my $copy = $1;
          print "was \n";
          print $copy . "\n";
          if (ref($y) eq "ARRAY") {
            print @{$y}[0] . "\n";
            print "there \n";
            if (ref(@{$y}[0]) eq "HASH") {
              print "where \n";
              if($copy =~ m/<children>(.*?)<\/children>/ms) {
                print "here \n";
                print $1 . "\n";
                my $sublist = section_replace_scalars($1, @{$y}[0]);
                $copy =~ s/<children>(.*?)<\/children>/$sublist/sm;
                $copy = section_replace_scalars($copy, @{$y}[0]);
              }
            } else {
              $copy =~ s/{list_item}.*?<ul.*?<\/ul>/@{$y}[0]/sm;
            }
            $list_replacement .= $copy;
          } elsif (ref($y) eq "") {
            $copy = section_replace_scalars($copy, $y);
            $list_replacement .= $copy;
          }
        }

        $template_html =~ s/<$X>(.*?)<\/$X>/$list_replacement/sm;
      }
    }
  }
}

replace();

print $template_html;

open(my $fh, '>', $out_html);
print $fh $template_html;
close $fh;