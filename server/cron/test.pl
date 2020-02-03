#!/usr/bin/perl
use utf8;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use Data::Dumper;
use strict;

# хак для Data::Dumper + utf8
$Data::Dumper::Useqq = 1;
$Data::Dumper::Useperl = 1;
{ no warnings 'redefine';
    sub Data::Dumper::qquote {
        my $s = shift;
        return "'$s'";
    }
}



my @errors=();
my $tmp_path='./';
my $filename='./cdek.xlsx';
my $result=go_parse(tmp_path=>$tmp_path,filename=>$filename,limit=>30);
print Dumper($result);

sub go_parse{
  my %arg=@_;
  my $filename=$arg{filename}; my $tmp_path=$arg{tmp_path};
  my $full_path=$tmp_path.$filename;
  my $parser;
  if($filename=~m/\.xlsx$/){
    $parser = Spreadsheet::ParseXLSX->new;
  }
  else{
    $parser = Spreadsheet::ParseExcel->new;
  }


  #print "v: ".$Spreadsheet::ParseXLSX::VERSION."\n";
  
  #print Dumper($parser);
  my $workbook;
  eval {
    $workbook = $parser->parse($full_path);
  };

  if($@){
    push @errors,$@;
  }
  elsif ( !defined $workbook ) {
      push @errors,$parser->error()
  }
  my $Cells = $workbook->{Worksheet}[0]->{Cells};
  my $row=0;
  print Dumper({cells=>$Cells});
  my $data=[];
  foreach my $c (@{$Cells}){
    my $str=[]; my $col=0;
    my $is_empty_cnt=0;

    while(1){
        last if($col>100);
        my $value=$c->[$col]->{_Value};
        $value='' unless($value);

        if(!$value || $value=~m/^\s+$/){
          $is_empty_cnt++;
          if($is_empty_cnt>30){
            $str=clear_empty_str($str);
            last
          }
        }
        else{
          $is_empty_cnt++;
        }
        push @{$str},$value;
        $col++;
    }
    $data->[$row]=$str;
    $row++;
    if($arg{limit} && $row>=$arg{limit}){
      last
    }
  }

  return {
    success=>scalar(@errors)?0:1,
    errors=>\@errors,
    data=>$data
  }
}

sub clear_empty_str{ # вычищаем пустые значения в конце строки
  my $str=shift;
  my @new_str=();
  my $need_clean=1;
  print Dumper({str=>$str});
  foreach my $v ( reverse(@{$str}) ){
    if(!$v || $v=~m/^\s+$/){ # значение пустое
      unless($need_clean){
         push @new_str,$v;
      }

    }
    else{ # значение не пустое
      push @new_str,$v;
      $need_clean=0;
    }
  }
  @new_str=reverse(@new_str);
  return \@new_str;
}



