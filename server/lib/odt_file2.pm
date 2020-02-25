package odt_file2;

use Data::Dumper;
use Archive::Zip;
use Template;
use File::Copy;
use OpenOffice::OODoc;
use strict;
use Image::Info qw(image_info);
use strict;
BEGIN {
    use Exporter ();
    our @ISA = "Exporter";
    our @EXPORT = ( '&odt_process');
}

### unoconv path
our $bin_dir = '/var/www/analytics';

sub odt_process {
  #print "Content-type: text/html\n\n";
    my $par = shift;

######### Проверим шаблон ##############################################

  if ($par->{template_path}){
    unless(-f($par->{template})){
      $par->{template_path} =~ s/\/$//;
      $par->{template} = $par->{template_path} . '/' . $par->{template};
    }
  }
  unless($par->{template}){
    error('параметр template не указан');
  }
  unless(-f($par->{template})){
    error("Шаблон не найден $par->{template}");
  }

######### Временная директория и файл ##################################
  my $ext;
  unless (-d($par->{tmp_dir})){
    $par->{tmp_dir} = './';
  } else{
    $par->{tmp_dir} =~ s/\/$//;
    $par->{tmp_dir} .= '/';
  }
    ($ext) = $par->{template} =~ /\.(\w+)$/;
    $par->{tmp_file} = $par->{tmp_dir} . get_fname() . '.' .$ext;

########################################################################
#print Dumper($par);
  odfWorkingDirectory($par->{tmp_dir});
  my $doc = odfDocument(file => $par->{template}) or die $!;

  # вставка картинок
  if($par->{vars}{img}){
    image($doc,$par->{vars}{img});
  }
  # вставка таблиц
  if($par->{vars}{table}){
    table($doc,$par->{vars}{table});
  }

  # вставка стилей
  if($par->{vars}{style}){
    style($doc,$par->{vars}{style});
  }

  $doc->save($par->{tmp_file}) or die error("\n~~~~~~~~~~~~~~~~~~~~~~~~ $!\n");
########################################################################

  my $zip = Archive::Zip->new();

  unless ( $zip->read( $par->{tmp_file} ) == Archive::Zip::AZ_OK ) {
    error("Archive::Zip->new() err", $par->{tmp_file});
  }

  my $content =  $zip->contents('content.xml');


  # from sv: автофикс "кривых" тэгов
  $|=1;

  { use utf8;
    #print "normalyze_start\n";
    Encode::_utf8_on($content);

    $content=~s{(\[\%.+?\%\])}{\n$1\n}gs;
    #open F,'>./log1.txt';print F $content; close F;
    #$content=~s{\[\%#.+?\%\]}{}gs;
    while($content=~m{(\[\%.+?\%\])}gs){
      my $command_first=$1; my $command=$1;
      print "$command_first\n";
      # !!!!!!!!!!!!!!!1 сделать фикс тэгов
      my @tags=($command=~m{(<.+?>)}gs);
      $command=~s/<.+?>//gs; $command=join('',@tags).$command;
      if($command ne $command_first){
        #print " - command1: $command ";
        # экранируем
        $command=~s/([\+\[\]\(\)\{\}\*\.\%\$\/])/\\$1/gs;
        $command_first=~s/([\+\[\]\(\)\{\}\*\.\%\$\/])/\\$1/gs;
        print qq{ ----- replace:\n\t\t\t{$command_first}\n\n\t\t\t{$command}\n\n\n};
        $content=~s/$command_first/$command/gs;
      }
    }

=cut
    while($content=~m{(\[\%.+?\%])}gs){
      my $command_first=$1;
      my $command=$1; $command=~s/<.+?>//gs;
      if($command ne $command_first){
        #print " - command1: $command ";
        # экранируем
        $command=~s/([\+\[\]\(\)\{\}\*\.\%\$\/])/\\$1/gs;
        $command_first=~s/([\+\[\]\(\)\{\}\*\.\%\$\/])/\\$1/gs;
        print " | $command\n";
        print qq{ ----- replace:\n\t\t\t{$command_first}\n\n\t\t\t{$command}\n\n\n};
        $content=~s/\[\%$command_first\%\]/\[\%$command\%\]/gs;
      }
    }
=cut
    #print "normalyze_end\n";
    Encode::_utf8_off($content);
    #open F,'>./log2.txt';print F $content; close F;
  }
  #print "\n===============================================\nCONTENT2:\n$content\n\n";
  ROWLOOP(\$content);


  #########################################
  my $template = Template->new();
  my $TTcontent;
  #print Dumper($par); exit;

  #print "\n\n$content\n\ntt process start\n";
  $template -> process( \$content, $par->{vars}->{data}, \$TTcontent ) || do {
    $par->{s}->print($template->error());
    die(Dumper($template->error()));
    #error( "output::add_template:template error: ". $template->error()."\n",$par->{tmp_file});
  };
  #print "ttcontent ok!\n";
  #print "\n\n$TTcontent\n\n"; # !!!!


  #########################################
  #print "zip_start\n";
  Encode::_utf8_off($TTcontent);
  $zip->contents('content.xml',$TTcontent);
  #print "zip_end\n";
  ### add manifest ######################
  my $manifest = $zip->contents('META-INF/manifest.xml');
  my @images = grep {$manifest !~ m|$_|is } grep /^Pictures\//, $zip->memberNames();
  my %mime = qw(jpeg image/jpeg jpg image/jpeg pcx image/x-pcx png image/png tif image/tiff gif image/gif);
  my $add_manifest;
  for (@images){
    my ($exp) = /\.([^\.]+$)/;
    if($exp){
      $add_manifest .= qq{ <manifest:file-entry manifest:media-type="$mime{$exp}" manifest:full-path="$_"/>\n};
    }
  }
  $add_manifest .= qq{ <manifest:file-entry manifest:media-type="" manifest:full-path="Pictures/"/>\n} if $manifest !~ /full-path="Pictures/;
  $manifest =~ s/(<\/manifest:manifest>)/$add_manifest$1/is;
  $zip->contents('META-INF/manifest.xml',$manifest);
  ### add manifest ######################

  if ($zip->overwrite() != Archive::Zip::AZ_OK){
    error( "error write file odt $par->{tmp_file}  tmp_file err\n" , $par->{tmp_file});
  };

  $zip = undef;
########################################################################
  
  if($par->{format} && $par->{format} !~ /od[ts]$/i){
    #print "unoconv -p8100 -f $par->{format} $par->{tmp_file}\n"; # !!!
    #print "unoconv -p8100 -f $par->{format} $par->{tmp_file}\n";
    `unoconv -p8100 -f $par->{format} $par->{tmp_file}`;

    #print "ZZ2\n";

    $par->{tmp_file} =~ s/\.\w+$//;
    $par->{tmp_file} = $par->{tmp_file} . '.' . $par->{format};

  } elsif($par->{format} =~m/od[ts]$/i || !$par->{format}){
    my $tmp_file = $par->{tmp_dir} . get_fname() . '.' .$ext;
    `${bin_dir}unoconv --stdout -p8100   -f $ext $par->{tmp_file} > $tmp_file`;
    unlink $par->{tmp_file};
    $par->{tmp_file} = $tmp_file;
  }


  if ($par->{result_dir} || $par->{result_file_name}){
    #print "1\n";
    if (!$par->{result_file_name}){
      ($par->{result_file_name}) = $par->{tmp_file} =~/^.*\/(.+)$/;
    }

    if ($par->{result_dir}){
      $par->{result_dir} .= '/' if $par->{result_dir} !~ /\/$/;
    }
    $par->{result_file_name} = $par->{result_dir} . $par->{result_file_name};
    print "move($par->{tmp_file},$par->{result_file_name})\n"; # !!!
    move($par->{tmp_file},$par->{result_file_name});
  } else{
    if (!$par->{upload_file_name}){
      ($par->{upload_file_name}) = $par->{tmp_file} =~/^.*\/(.+)$/;
    }
    
    if($par->{s}){
      my $s=$par->{s};
      $s->{vars}->{print_header}=1;
      $s->{APP}->{STATUS}=100;
      push @{$s->{APP}->{HEADERS}},q{Content-Type: application/x-force-download};
      push @{$s->{APP}->{HEADERS}},qq{Content-Disposition:attachment; filename=\"dogovor.doc\"};
      $s->{stream_file}=$par->{tmp_file};
      $s->{stream_file_need_unlink}=1;

    }


  }
}
1;
#######################################################################################
sub image {
  my $doc = shift;
    my $data = shift;
  my $i;

  for my $im (keys %{$data}){

    for my $para ($doc->selectElementsByContent('\[%#?\s*'.$im.'.*?%\]')){
      $i++;
      my $tag  = $doc->getText($para);
      my ($pos) = $tag =~ /p:([\d.,\-\+]+)/is;
      my ($siz) = $tag =~ /s:([\d.,]+|auto)/is;

      my ($width,$height);
      if ($siz =~ /^auto$/i  || !$siz){
        if( $data->{$im}{width} && $data->{$im}{height} ){
          ($width,$height) = ($data->{$im}{width},$data->{$im}{height});
        }else{
          my $inf = image_info($data->{$im}{file});
          my $res;
          if( ref($inf->{resolution}) eq 'ARRAY'){
            $res = $inf->{resolution}[0] * 1;
          }
          $res = $res ? $res : 96;
          ($width,$height) = ($inf->{width}*2.54/$res,$inf->{height}*2.54/$res);
        }
      } else{
        ($width,$height) = split(",", $siz);
      }
      $doc->setText($para,'');
      my @pos1;
      if( $pos || $data->{$im}{x} && $data->{$im}{y} ){
        my ($x,$y);
        if ( $pos ){
          ($x,$y) = split(",", $pos);
        }else{
          ($x,$y) = ($data->{$im}{x}, $data->{$im}{y});
        }
        @pos1 = (
          'text:anchor-type'=>'char',
          'svg:x'=>"${x}cm",
          'svg:y'=>"${y}cm"
        );
        $doc->createImageStyle(
          "NewImageStyle",
          'properties'=>{
            'style:run-through'=>"background",
            'style:wrap'=>"run-through",
            'style:number-wrapped-paragraphs'=>"no-limit",
            'style:vertical-pos'=>"from-top",
            #'style:vertical-rel'=>"paragraph",
            'style:horizontal-pos'=>"from-left",
            #'style:horizontal-rel'=>"paragraph"
          }
        );
      }
      $doc->createImageElement(
        $im.$i,
        'style'=>'NewImageStyle',
        'attachment' => $para,
        'import' => $data->{$im}{file},
        'size' => "${width}cm, ${height}cm",
        @pos1
      );
      $doc->imageAttribute($im.$i,
        'xlink:show'=>'embed',
        #'xlink:type'=>"simple"
      );
    }
  }

  return undef;
}
#######################################################################################
sub  error{
  print "Content-type: text/html; charset=utf8\n\n";
  if (@_[1]){
    unlink @_[1];
  }
  die @_[0];
}
#######################################################################################
sub ROWLOOP{
  ${@_[0]} =~s/(<table:table-row.+?<\/table:table-row>)/_ROWLOOP($1)/sge;
}
#######################################################################################
sub _ROWLOOP{
  my $t = shift;
  if ($t =~ s/\[\%\s*ROWLOOP\s+([^\]]+?)\%\]//s){
    $t = "[%FOREACH $1%]". $t .'[%END%]';
  }
  $t;
}
#######################################################################################
sub get_fname{
  my $a='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  my $key='';
    foreach my $k (1..20){
      $key.=substr($a,int(rand(length($a))),1)
  }
  return $key;
}
#######################################################################################
sub table {
  my $doc =  shift;
    my $data = shift;
  my $numtable = 0;

  for my $tab (keys %{$data}){

    for my $para ($doc->selectElementsByContent('\[%\s*'.$tab.'\s*%\]')){

      $doc->setText($para,'');

      my $table = $doc->insertTable(
        $para,
        $tab.$numtable,
        $data->{$tab}->{val}->{lines},
        $data->{$tab}->{val}->{columns},
        'table-style'=>$data->{$tab}->{table_style},
        'text-style'=>$data->{$tab}->{text_style},
        'cell-style'=>$data->{$tab}->{cell_style});
      for (my $i = 0 ; $i < $data->{$tab}->{val}->{lines}; $i++)
      {
        for (my $j = 0 ; $j < $data->{$tab}->{val}->{columns}; $j++)
        {
          my $cell = $doc->getTableCell($tab.$numtable, $i, $j);
          foreach (@{$data->{$tab}->{val}->{cellvalues}[$i][$j]}){
            $doc->appendParagraph(
              attachment=>$cell,
              style => $_->{style},
              text=>$_->{text}
            );
          }
        }
      }
      $numtable++;
    }
  }
}
#######################################################################################
sub style {
  my $styles =  shift;
    my $data = shift;
  for(@{$data}){
    $styles->createStyle($_->{name},
            properties  => $_->{properties},
            family    => $_->{family},
            parent    => $_->{parent},
    );
  }
    return undef;
}
#######################################################################################
sub p{
  print "Content-type: text/html; charset=windows-1251\n\n";
  #print "Content-type: text/html; charset=utf8\n\n";
    print '<pre>';
}
sub xmp{
  print "Content-type: text/html; charset=utf8\n\n";
    print '<xmp>';
}


__END__
