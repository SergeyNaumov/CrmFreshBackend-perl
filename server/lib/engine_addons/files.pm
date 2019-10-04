use utf8;
use strict;
sub save_file{
  my $s=shift; my $filename=shift; my $data=shift;
  open (my $descript,'>:encoding(UTF-8)',$filename) or print "error write $filename\n$!\n";
  print $descript $data;
  close $descript;
}
sub print_file{
  my $s=shift; my $filename=shift;
  #open (my $fh,'<:encoding(UTF-8)',$filename) or print "error read $filename\n$!\n";
  open (my $fh,'<',$filename) or print "error read $filename\n$!\n";
  while(my $row = <$fh>){
    #chomp $row;
    $s->print("$row");
  }
  close $fh;
  return $s;
}

sub read_file{
  my $s=shift; my $filename=shift;
  open (my $fh,'<:encoding(UTF-8)',$filename) or print "error read $filename\n$!\n";
  my $result='';
  while(my $row = <$fh>){
    $result.=$row;
    #$s->print("$row");
  }
  close $fh;
  return $result;
}
sub readdir{
  my $s=shift;
  my $dir=shift;

  opendir (DIR, $dir);
  my @files=();
  my @folders=();
  my @list=();
  while(my $file=readdir(DIR)){push @list,$file;}
  @list=sort(@list);  
  foreach my $file (@list){   
    next if ($file eq '.' || $file eq '..');
    my $fobject;
    Encode::_utf8_on($file);
    $fobject->{name}=$file;
    my $fullpath=qq{$dir/$file};
    $fullpath=~s|\/+|\/|g;
    #print "$fullpath<br/>";
    if(-d $fullpath){
      $fobject->{type}='dir';
      push @folders,$fobject;
    }
    else{
      if($fobject->{name} =~m/\.(gif|png|jpe?g|bmp)$/){
        $fobject->{type}='picture';
      }
      elsif($fobject->{name} =~m/\.html?$/){
        $fobject->{type}='html';
      }
      elsif($fobject->{name} =~m/\.css$/){
        $fobject->{type}='css';
      }
      elsif($fobject->{name}=~m/\.(7z|rar|zip|tar\.bz2|tar\.gz)$/){
        $fobject->{type}='archive';
      }
      else{
        $fobject->{type}='file';
      }     
      push @files,$fobject;
    }
    undef $fobject;
  }
  close DIR;
  @list=(@folders,@files);
  return \@list;
}
return 1;
