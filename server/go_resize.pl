#!/usr/bin/perl
use lib './';
use lib './lib';
use Engine;
#use CRM::FormFiles;
use Data::Dumper;
#use Image::Magick;
use strict;

my $config='article';
our $form={};
my $config=$ARGV[0];
unless($config){
  print "use command: ./go_resize.pl [config_name]"
}
$config=~s/\.pl$//;
$config=~s/^.+\///;
unless(-f './conf/'.$config.'.pl'){
  print "file ./conf/$config.pl not found\n";
}
do './conf/'.$config.'.pl';

#print Dumper($form);
my $where="where id=32";

my $s=Engine->new(env=>{});
$s->{db}=$s->{connects}->{crm_write};
foreach my $f (@{$form->{fields}}){

  if($f->{type} eq 'file' && $f->{resize} && (ref($f->{resize}) eq 'ARRAY')){
    my $list=$s->{db}->query(
      query=>"SELECT $form->{work_table_id} id, $f->{name} v from $form->{work_table} $where",
      
    );
    foreach my $l (@{$list}){
      #resize_for_field($l,$f);
    }
  }
  if($f->{type} eq '1_to_m'){
    
    foreach my $f2 (@{$f->{fields}}){
      pre($f2);
      if($f2->{type} eq 'file' ){
        
        my $list=$s->{db}->query(
          query=>"SELECT $f->{table_id} id, $f2->{name} v from $f->{table} where $f->{foreign_key}=32"
        );
        
        foreach my $l (@{$list}){

          resize_for_field($l,$f2);
        }
        
      }
    }
  }
}

sub resize_for_field{
  my $item=shift; my $f=shift; # field
  my $filename=$item->{v}; # $l->{id}
  return unless($filename);
  if($filename=~m/^(.+)\.([^\.]+)$/){
    my ($filename_without_ext,$ext)=($1,$2);
    foreach my $r (@{$f->{resize}}){
        my %arg=%{$r};
        my $to_file=$r->{file};
        $to_file=~s/<\%filename_without_ext\%>/$filename_without_ext/;
        $to_file=~s/<\%ext\%>/$ext/;
        $arg{to}=$f->{filedir}.'/'.$to_file;
        $arg{from}=$f->{filedir}.'/'.$filename;
        delete $arg{file};
        delete $arg{description};
        resize(%arg)
    }
  }
}
#CRM::read_conf(s=>$s,config=>'article',);
sub resize{
    my %arg=@_;
    my $image = Image::Magick->new();
    $image->Read($arg{from});
    my ($ox,$oy)=$image->Get('base-columns','base-rows');
    my ($k,$nx,$ny);
    if($arg{quality}=~m{^\d+$}){
        $image->Set( quality => $arg{quality} );
    }
    if($arg{size} && !$arg{width} && !$arg{height}){
      if($arg{size}=~m/^(\d+)x(\d+)$/){
        ($arg{width},$arg{height})=$1,$2
      }
    }
    if(!$arg{height}){
        if($arg{width}>$ox){
          # Тимоненкова попросила сделать так, что если у нас ресайз вида 800x0, А мы загружаем картинку меньшую, чем
          # 800 по ширине -- чтобы она оставалась без изменений, кладём на пропорции
          $image->Write($arg{to});
          return;
          
        }
        $k=$oy/$ox;$arg{height}=int($arg{width}*$k);
    }
    elsif(!$arg{width}){
        $k=$ox/$oy;$arg{width}=int($arg{height}*$k);
    }
    else{
        $ny=int(($oy/$ox)*$arg{width});
        $nx=int(($ox/$oy)*$arg{height});
    }

    if($arg{width} eq $arg{height}){
        if($ox ne $oy){
            my $min=minarg($ox,$oy);
            $image->Crop(geometry=>$min.'x'.$min, gravity=>'center');
        }
        $image->Resize(geometry=>'geometry', width=>$arg{width}, height=>$arg{height});
    }
    if($nx>=$arg{width}){ # горизонтально ориентированная
        $nx=$arg{width} if($nx<$arg{width});
        $image->Resize(geometry=>'geometry', width=>$nx, height=>$arg{height});
        if($nx>$arg{width}) { #Если ширина получилась больше 200
            my $nnx=int(($nx-$arg{width})/2); #Вычисляем откуда нам резать
            $image->Crop(geometry=>$arg{width}.'x'.$arg{height}, gravity=>'center');
        }
    }
    else{ # вертикально ориентированная
        $ny=$arg{height} if($ny < $arg{height});
        $image->Resize(geometry=>'geometry', width=>$arg{width}, height=>$ny);
    
        if($ny>$arg{height}) {
            my $nny=int(($ny-$arg{height})/2); #Вычисляем откуда нам резать
            $image->Crop(geometry=>$arg{width}.'x'.$arg{height}, gravity=>'center');
        }
    }

    if($arg{composite_file}){
        my $layer = new Image::Magick;
        $layer->Read($arg{composite_file});
        if($arg{composite_resize}){
            $layer->Resize(geometry=>$arg{composite_resize});
        }
        $arg{composite_gravity}='center' unless($arg{composite_gravity});
        $image->Composite(image=>$layer,gravity=>$arg{composite_gravity}); #,x=>10,y=>10
         # compose=>'Atop',x=>10, y=>20
         pre(\%arg);
        $layer=undef;
    }
    $image->Quantize(colorspace=>'gray') if($arg{grayscale});

    #  $img->Strip;
    $image->Write($arg{to});
    chmod 0664, $arg{to};
    $image=undef;
}

sub pre{
  print Dumper($_[0]);
}