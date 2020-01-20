package coresubs;
use Data::Dumper;
use strict;
use Exporter 'import';
use Template;
use MIME::Lite;
use MIME::Base64;
use JSON;
use Encode;
use Date::Parse qw/ str2time /;




our @EXPORT_OK = qw/print_error  print_header print_template html_strip send_mes encodeJSON next_date pre cur_time cur_date/;
# хак для Data::Dumper + utf8
$Data::Dumper::Useqq = 1;
$Data::Dumper::Useperl = 1;
{ no warnings 'redefine';
    sub Data::Dumper::qquote {
        my $s = shift;
        return "'$s'";
    }
}
# хак для Data::Dumper + utf8

my $header_printed=0;




sub print_error{
  print $_[0]; exit;
}

sub pre{
  print '<pre>'.Dumper($_[0]).'</pre>';
}

sub print_header{
  return if($header_printed);
  print "Content-type: text/html; charset=utf-8\n\n";
  $header_printed=1;
}

sub print_template{
  my %arg=@_;
  my $out;
  unless($arg{dir}){
    if($arg{template}=~m/^(.+)\/([^\/]+)$/){
      $arg{dir}=$1; $arg{template}=$2;
    }
    else{
      $arg{dir}='./'
    }
    
  }
  #pre(\%arg);
  my $template = Template->new(
    ENCODING => $arg{utf8}?'utf8':'',
    INCLUDE_PATH=>$arg{dir}
  );
  
  $template->process($arg{template},$arg{vars},\$out) || die $template->error();
  if($arg{print}){
    print $out;
    return
  }
  return $out;
  
}

sub html_strip{
  my $s=shift;
  $s=~s/</&lt;/gs;
  $s=~s/>/&gt;/gs;
  $s=~s/"/&quot;/gs;
  return $s;
}

sub send_mes{
	my $opt=shift;
	if($opt->{to}!~/@/){
		&print_error(qq{Невозможно отравить сообщение на адрес '$opt->{to}'});
		return;
	}
  
  #Encode::_utf8_off($opt->{subject}) if(utf8::is_utf8($opt->{subject}));
	#Encode::_utf8_off($opt->{message}) if(utf8::is_utf8($opt->{message}));
        
        
  $opt->{return_path}=$opt->{from} unless($opt->{return_path});
  #$opt->{subject}=encode('MIME-Header', decode('utf8', $opt->{subject}));
  
  
	my $letter = MIME::Lite->new(
		From => $opt->{from},
			To => $opt->{to},
			'Return-Path' => $opt->{from},
			Subject =>$opt->{subject},
			Type=> 'multipart/mixed',
	) || &print_error("Can't create $!");
  
	if($opt->{template} && !$opt->{message}){
		$opt->{message}=print_template(template=>$opt->{template},vars=>$opt->{vars});
	}

  $letter->attach (
		Type => 'text/html; charset=utf8',
		Data => $opt->{message}
	) or warn "Error adding the text message part: $!\n";

#	&print_header;
#	print Dumper($opt);

	foreach my $f (@{$opt->{files}}){

			$letter->attach(
				Type => 'AUTO',
				Disposition => 'attachment',
				Filename => $f->{filename},
				Path => $f->{full_path},
			);

	}

  $letter->send() || &print_error("Can't send $!");
}

sub encodeJSON{
    #my($arrayRef) = @_;
    return JSON->new->encode($_[0]); # utf8->
    #return $JSONText;
}

sub next_date{
  my $d=shift;
  my ($mday,$mon,$year)=(localtime(str2time($d)+86400))[3,4,5];
  return sprintf("%04d-%02d-%02d",$year+1900,$mon+1,$mday);
}

sub cur_date{
  my $delta=shift;
  $delta=0 unless($delta);
  my ($mday,$mon,$year)=(localtime(time+86400*$delta))[3,4,5];
  return sprintf("%04d-%02d-%02d",$year+1900,$mon+1,$mday);
}

sub cur_time{
  my $delta_sec=shift;
  $delta_sec=0 unless($delta_sec);
  my ($sec,$min,$hour,$mday,$mon,$year)=(localtime(time()+$delta_sec))[0,1,2,3,4,5];
  return sprintf("%04d-%02d-%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
}
sub to_translit{
    ($_)=@_;
    Encode::_utf8_on($_);
    {
      
      use utf8
      #
      # Fonetic correct translit
      #

      s/Сх/S\'h/; s/сх/s\'h/; s/СХ/S\'H/;
      s/Ш/Sh/g; s/ш/sh/g;

      s/Сцх/Sc\'h/; s/сцх/sc\'h/; s/СЦХ/SC\'H/;
      s/Щ/Sch/g; s/щ/sch/g;

      s/Цх/C\'h/; s/цх/c\'h/; s/ЦХ/C\'H/;
      s/Ч/Ch/g; s/ч/ch/g;

      s/Йа/J\'a/; s/йа/j\'a/; s/ЙА/J\'A/;
      s/Я/Ja/g; s/я/ja/g;

      s/Йо/J\'o/; s/йо/j\'o/; s/ЙО/J\'O/;
      s/Ё/Jo/g; s/ё/jo/g;

      s/Йу/J\'u/; s/йу/j\'u/; s/ЙУ/J\'U/;
      s/Ю/Ju/g; s/ю/ju/g;

      s/Э/E\'/g; s/э/e\'/g;
      s/Е/E/g; s/е/e/g;

      s/Зх/Z\'h/g; s/зх/z\'h/g; s/ЗХ/Z\'H/g;
      s/Ж/Zh/g; s/ж/zh/g;

      tr/
      абвгдзийклмнопрстуфхцъыьАБВГДЗИЙКЛМHОПРСТУФХЦЪЫЬ/
      abvgdzijklmnoprstufhc\"y\'ABVGDZIJKLMNOPRSTUFHC\"Y\'/;
    };
    Encode::_utf8_off($_);
    return $_;
}
return 1;
END { }
