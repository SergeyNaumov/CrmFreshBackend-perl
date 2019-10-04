package ProtocolAnalytic::Params;
use strict;
use Date::Parse qw/ str2time /;
use Data::Dumper;
# 'not_place_location','region_is_not_delivery'
my $params_data={
  protocols=>{
    attr_filters=>[
      #{par=>'winner',field=>'winner',type=>'bool'},
      #{par=>'not_admitted',field=>'not_admitted',type=>'bool'},
      #{par=>'max_down',field=>'max_down',type=>'bool'},
      {par=>'cena_contrakta_low',field=>'cena_contrakta',type=>'lt',regexp=>qr/^\d+$/},
      {par=>'cena_contrakta_hi',field=>'cena_contrakta',type=>'gt',regexp=>qr/^\d+$/},
      {par=>'max_percent_low',field=>'max_percent',type=>'lt',regexp=>qr/^(\d\d?|100)$/},
      {par=>'max_percent_hi',field=>'max_percent',type=>'gt',regexp=>qr/^(\d\d?|100)$/},
      {par=>'otr_id',field=>'cur_linehi',regexp=>qr/^\d+$/},
      {par=>'subotr_id',field=>'cur_linelo',regexp=>qr/^\d+$/},
      {par=>'from_dat',field=>'dat',type=>'lt',par_enable=>'use_dat',is_timestamp=>1},
      {par=>'to_dat',field=>'dat',type=>'gt',par_enable=>'use_dat',is_timestamp=>1}
    ],
    keywords=>[
      {field=>'own_inn',words=>'owner_inn',words_minus=>'own_inn_minus_'},
      {field=>'own_kpp',words=>'owner_kpp',words_minus=>'own_kpp_minus_'},
      {field=>'header',words=>'header',words_minus=>'minus_word_header'},
      {field=>'inn',words=>'inn',words_minus=>'minus_word_inn'},
      {field=>'kpp',words=>'kpp',words_minus=>'minus_word_kpp'},
    ],
    country_reg_city=>{
      mn=>{
        region=>{form_field=>'region',index_field=>'region'},
        district=>{form_field=>'district_id',index_field=>'district'},
        city=>{form_field=>'city_id',index_field=>'city_id'},

      },
      mp=>{
        #country=>{form_field=>'delivery_country_id',index_field=>'delivery_country_id'},
        district=>{form_field=>'delivery_district_id',index_field=>'delivery_district_id'},
        region=>{form_field=>'delivery_region_id',index_field=>'delivery_region_id'},
        city=>{form_field=>'delivery_city_id',index_field=>'delivery_city_id'},
      },
      region_is_not_delivery_chk=>'region_is_not_delivery', # Место нахождения не соответствует месту поставки
      not_place_location_chk=>'not_place_location' # Все МН кроме выбранных
    }
  },
  tenders=>{
    attr_filters=>[
      #{par=>'winner',field=>'winner',type=>'bool'},
      #{par=>'not_admitted',field=>'not_admitted',type=>'bool'},
      #{par=>'max_down',field=>'max_down',type=>'bool'},
      {par=>'cena_contrakta_low',field=>'cena_contrakta',type=>'lt',regexp=>qr/^\d+$/},
      {par=>'cena_contrakta_hi',field=>'cena_contrakta',type=>'gt',regexp=>qr/^\d+$/},
      {par=>'otr_id',field=>'cur_linehi',regext=>qr/^\d+$/},
      {par=>'subotr_id',field=>'cur_linelo',regext=>qr/^\d+$/},
      {par=>'from_dat',field=>'startdate',type=>'lt',par_enable=>'use_dat',is_timestamp=>1},
      {par=>'to_dat',field=>'stopdate',type=>'gt',par_enable=>'use_dat',is_timestamp=>1}
    ],
    keywords=>[
      {field=>'header',words=>'header',words_minus=>'minus_word_header'},
      {field=>'inn',words=>'owner_inn'},
      {field=>'firm',words=>'own_firm'},
    ],
    country_reg_city=>{
      mn=>{
        country=>{form_field=>'country_id',index_field=>'country'},
        region=>{form_field=>'region',index_field=>'region'},
        #district=>{form_field=>'district_id',index_field=>'district'},
        city=>{form_field=>'city_id',index_field=>'city_id'},

      },
      mp=>{
        country=>{form_field=>'delivery_country_id',index_field=>'delivery_country_id'},
        #district=>{form_field=>'delivery_district_id',index_field=>'delivery_district_id'},
        region=>{form_field=>'delivery_region_id',index_field=>'delivery_region_id'},
        city=>{form_field=>'delivery_city_id',index_field=>'delivery_city_id'},
      },
      region_is_not_delivery_chk=>'region_is_not_delivery', # Место нахождения не соответствует месту поставки
      not_place_location_chk=>'not_place_location' # Все МН кроме выбранных
    }
  }
};


sub get_search_params{
  my $s=shift;
  my $params;
  my $db=$s->{connects}->{rosexport};
  { # ИНН заказчика
    my $h=$s->param('owner_inn');
    if($h=~m/^\d+$/){
      $params->{inn_owner}=$h;
      
    }
    my $kpp=$s->param('owner_kpp');
    if($h=~m/^\d+$/){
      $params->{kpp_owner}=$kpp;
    }
    $params->{owner_firm}=$db->query(query=>q{select firm from moderator_comp where inn=?}.(($kpp=~m/^\d+$/)?" AND kpp=$kpp":''),onevalue=>1,values=>[$h]);
  }
  { # Поставщик
    my $h=$s->param('inn');
    if($h=~m/(\d+)/){
      $params->{inn}=$h;
      my $kpp=$s->param('kpp');
      if($kpp=~m/^\d+$/){
        $params->{kpp}=$kpp;
      }
      $params->{firm}=$db->query(query=>q{select firm from moderator_comp where inn=?}.(($kpp=~m/^\d+$/)?" AND kpp=$kpp":''),onevalue=>1,values=>[$h]);
    }

  }
  
  
    

  { # ключевые слова
    if(my $h=ecran_ind($s->param('header'))){
      #print "h: '$h'\n";
      $params->{header}=$h;
    }
  }
  { # дата размещения заявки
    my $from_dat=$s->param('from_dat');
    my $to_dat=$s->param('to_dat');
    if($from_dat || $to_dat){
      if($from_dat){$params->{from_dat}=$from_dat};
      if($to_dat){$params->{to_dat}=$to_dat};
    }
  }

  { # цена контракта
    my $cena_contrakta_low=$s->param('cena_contrakta_low');
    my $cena_contrakta_hi=$s->param('cena_contrakta_hi');
    if($cena_contrakta_low=~m/^\d+(\.\d+)?$/){$params->{cena_contrakta_low}=$cena_contrakta_low}
    if($cena_contrakta_hi=~m/^\d+(\.\d+)?$/){$params->{cena_contrakta_hi}=$cena_contrakta_hi}
  }
  { # процент снижения
    my $max_percent_low=$s->param('max_percent_low');
    my $max_percent_hi=$s->param('max_percent_hi');
    if($max_percent_low=~m/^(\d\d?|100)$/){$params->{max_percent_low}=$max_percent_low}
    if($max_percent_hi=~m/^(\d\d?|100)$/){$params->{max_percent_hi}=$max_percent_hi}
  }
  #max_percent_low max_percent_hi
  { # отрасли / подотрасли
    #my @otr_id_list=$s->param_mas('otr_id');
    my @otr_id=$s->param_mas('otr_id');
    @otr_id=grep(/^\d+$/,@otr_id);
    if(scalar(@otr_id)){
      @{$params->{otr_list}}=map {$_->{header}} @{$db->query(query=>'SELECT header from otr where id IN ('.join(',',@otr_id).')')};
    }

    my @subotr_id=$s->param_mas('subotr_id');
    @subotr_id=grep(/^\d+$/,@subotr_id);
    if(scalar(@subotr_id)){
      my $query=q{select concat(o.header,'/',s.header) header from otr o join subotr s ON (o.id = s.otr) where s.id IN (}.join(',',@subotr_id).')';
      if(scalar(@otr_id)){
        $query.=' AND o.id NOT IN ('.join(',',@otr_id).')';
      }
      $query.=' ORDER by o.header, s.header';


      @{$params->{subotr_list}}=map {$_->{header}} @{$db->query(query=>$query)};
    }
  }
  
  { # регионы
    my @region=$s->param_mas('region');
    @region=grep(/^\d+$/,@region); my @exclude_regions=();
    if(scalar(@region)){
      my %all_regions=map {$_=>1} @region;
      # для того, чтобы минимизировать "простыню" из регионов для округов
      my $district_list={map {$_->{id}=>{header=>$_->{header}}} @{$db->query(query=>'select district_id id,header from district')}};
      foreach my $district_id (keys %{$district_list}){
          $district_list->{$district_id}->{regions}={map {$_->{id}=>$all_regions{$_->{id}}} @{$db->query(query=>"SELECT region_id id from region where district=$district_id")}};

          # Если все регионы внутри округа включены -- добавляем в список параметров поиска округ и исключаем регионы из списка
          my $flag=1;
          foreach my $r (keys %{$district_list->{$district_id}->{regions}}){
              unless($district_list->{$district_id}->{regions}->{$r}){
                $flag=0; last;
              }
          }
          if($flag){ # да, все регионы внутри округа включены
              push @{$params->{fo_list}},$district_list->{$district_id}->{header};
              foreach my $r (keys %{$district_list->{$district_id}->{regions}}){
                push @exclude_regions,$r;

              }
          }

      }


      #my $list=$db->query(query=>q{select header from region where region_id IN (}.join(',',@region).') ORDER by header');
      my $query=q{select concat(d.header,' / ',r.header) header from region r join district d ON (d.district_id = r.district) where r.region_id IN (}.join(',',@region).')';
      if(scalar(@exclude_regions)){
        $query.=' AND r.region_id not IN ('.join(',',@exclude_regions).')';
      }
      $query.=' ORDER by header';
      my $list=$db->query(query=>$query);
      @{$params->{region_list}}=map {$_->{header}} @{$list};
    }
  }
  
  $params->{tenders_view}=$s->param('tenders_view')?1:0;
  print Dumper({params=>$params});
  return $params
}

sub get_sph_query{ # +

  my %arg=@_;
  my @filter_mas=();
  #my $params=get_params_for_protocols();
  my $data;
  if($arg{type} eq 'protocols'){
    $data=$params_data->{protocols};
  }
  else{
    $data=$params_data->{tenders};
    push @filter_mas,"startdate>=1072904400";
  }



  foreach my $p (@{$data->{attr_filters}}){
    my @v=$Work::engine->param_mas($p->{par});
    unless($p->{regexp}){
      if($p->{is_timestamp}){
        $p->{regexp}=qr/^\d+[\-\.]\d+[\-\.]\d+$/;
      }
      else{
        $p->{regexp}=qr/^\d+$/
      }
    }
    @v=grep(/$p->{regexp}/,@v);

    if(scalar(@v) && (!$p->{par_enable} || $Work::engine->param($p->{par_enable}))){
        if($p->{is_timestamp}){

          @v=map {
            if($_=~m/^(\d+)\.(\d+)\.(\d+)$/){
              $_="$3-$2-$1";
            }
            str2time $_
          } @v
        }
        if($p->{type} eq 'bool'){
          push @filter_mas,"$p->{field}=1" if(scalar(@v));
        }
        elsif($p->{type} eq 'lt'){
          push @filter_mas,"$p->{field}>=$v[0]"
        }
        elsif($p->{type} eq 'gt'){
          push @filter_mas,"$p->{field}<=$v[0]"
        }
        else{
            push @filter_mas,join (' OR ',map {"$p->{field}=$_"} @v)
        }
    }

  }
  my $FILTER=(scalar(@filter_mas))?(join(' AND ',map{"($_)"} @filter_mas)):'';
  # Обработка блоков МП и МН
  if(exists $data->{country_reg_city}){
    my @or_filters=();
    my $newfilter=''; my $region_ors='';

    my $mn=$data->{country_reg_city}->{mn};
    my $mp=$data->{country_reg_city}->{mp};
    my $region_is_not_delivery=$Work::engine->param($data->{country_reg_city}->{region_is_not_delivery_chk});
    my $not_place_location=$Work::engine->param($data->{country_reg_city}->{not_place_location_chk});
    # {country_reg_city}->{mn}->{form_fields|index_fields}
    # {country_reg_city}->{mp}
    my $and_or=' OR ';
    if($region_is_not_delivery){ # Если регион не соответствует месту поставки



      foreach my $ftype (qw(city discrict region country)){
        my $ind_mn=$mn->{$ftype}->{index_field};
        my $ind_mp=$mp->{$ftype}->{index_field};

        ### МН
        if($ind_mn){
          my @mn_values=$Work::engine->param_mas($mn->{$ftype}->{form_field});
          @mn_values=grep(/^\d+$/,@mn_values);
          if(scalar(@mn_values)){
            push @or_filters,'( '.(join ' OR ',(map {"$ind_mn = $_ "} @mn_values)).' )';
          }
        }
        # МП
        if($ind_mp){
          my @mp_values=$Work::engine->param_mas($mp->{$ftype}->{form_field});
          @mp_values=grep(/^\d+$/,@mp_values);
          if(scalar(@mp_values)){

              if($ftype eq 'district'){
                $region_ors.=' AND ' if($region_ors);
                $region_ors.=get_regions_from_district(db=>$arg{db},delivery_district=>\@mp_values,region_ind=>$mn->{region}->{index_field},and_or=>'AND',eq=>'<>');
              }
              elsif($ftype eq 'region'){
                $region_ors.=' AND ' if($region_ors);
                $region_ors.=join 'AND' , (map {' '.$mn->{region}->{index_field}." <> $_ "} @mp_values );
              }
              else{
                push @or_filters,'( '.(join ' OR ',(map {"$ind_mp = $_ "} @mp_values)).' )';
              }


          }

        }
      }
    }
    else{ # галка "регион не соответствует месту поставки" выключена, собираем регионы


      my $eq='='; my $and_or='OR';
      if($not_place_location){
        $eq='<>';
        $and_or='AND';

      }

      foreach my $ftype (qw(country discrict region city)){
        my $ind_mn=$mn->{$ftype}->{index_field};
        my $ind_mp=$mp->{$ftype}->{index_field};
        #&::print_header;
        #&::pre($and_or);
        if($ind_mn){
          my @mn_values=$Work::engine->param_mas($mn->{$ftype}->{form_field}); @mn_values=grep(/^\d+$/,@mn_values);
          if($ftype eq 'district' && scalar(@mn_values)){
              my $r_ors=get_regions_from_district(
                db=>$arg{db},
                delivery_district=>\@mn_values,
                region_ind=>$mn->{region}->{index_field},
                and_or=>$and_or,eq=>$eq
              );
              if($r_ors){
                $region_ors.=" $and_or " if($region_ors);
                $region_ors.=$r_ors
              }
          }
          elsif(scalar(@mn_values)){
            $region_ors.=" $and_or " if($region_ors);
            $region_ors.=join " $and_or ",(map {"$ind_mn $eq $_ "} @mn_values);

          }
        }
      }
    }

    push @or_filters,'( '.$region_ors.' )' if($region_ors);
    my $region_ors='';
    for my $ftype ( qw/city district region country/ ){
      my $ind_mp=$mp->{$ftype}->{index_field}; next unless($ind_mp);
      my @mp_values=$Work::engine->param_mas($mp->{$ftype}->{form_field});
      @mp_values=grep(/^\d+$/,@mp_values);
      next unless(scalar(@mp_values));
      if($ftype eq 'district'){
        #$region_ors=get_regions_from_district($par->{$field},'delivery_region_id');
        $region_ors=get_regions_from_district(db=>$arg{db},delivery_district=>\@mp_values,region_ind=>$mp->{region}->{index_field},eq=>'<>');

      }
      elsif($ftype=~m/^(region|city)$/){
        $region_ors.=' OR ' if($region_ors);
        $region_ors.=join ' OR ' , (map {"$ind_mp = $_ "} @mp_values );
      }
      else{
        push @or_filters,'( '.(join ' OR ',(map {"$ind_mp = $_ "} @mp_values)).' )';
      }
    }

    push @or_filters,'( '.$region_ors.' )' if($region_ors);
    my $PLACE_AND_OR=' AND ';
    if($Work::engine->param('place_or')){
      $PLACE_AND_OR=' OR '
    }

    if($FILTER && scalar(@or_filters)){

      my $and_or_inner;

      if($not_place_location || $region_is_not_delivery || (!$not_place_location && !$region_is_not_delivery)){
        $and_or_inner=' AND ';
      }
      else{
        $and_or_inner=' OR ';
      }
      $FILTER='('.$FILTER.')';
      $FILTER = join ($PLACE_AND_OR,($FILTER,join($and_or_inner,@or_filters)));
    }
    elsif(scalar(@or_filters)){
      if($region_is_not_delivery || $not_place_location){
      $FILTER =' ( '.join(' '.$PLACE_AND_OR.' ',@or_filters).' ) ';
      }
      else{
        $FILTER ='( '.join(' '.$PLACE_AND_OR.' ',@or_filters).' ) ';
      }
    }


  } # / обработка МН и МП

  #&::pre(\@filter_mas);
  return {
    filter=>$FILTER?$FILTER:'1',
    index=>($arg{type} eq 'protocols')?'katalog_1_protocols':'katalog_1_and_archive_all',
    match=>process_keywords($data->{keywords}),
  };

  #return $params;
}

sub get_sph_sql{
  my %arg=@_;
  my $par_sph=$arg{par_sph};

}
sub get_regions_from_district{ # +
  my %arg=@_;
  # (delivery_district=>\@delivery_district,region_ind=>$mp->{region}->{index_field},and_or=>'AND',eq=>'<>')
  $arg{eq}='=' unless($arg{eq});
  $arg{and_or}='OR' unless($arg{and_or});
  my $where=''; my $db=$arg{db};
  my $reglist=$db->run_query(query=>'SELECT * from region WHERE district IN ('.join(',',@{$arg{delivery_district}}).')');
  foreach my $r (@{$reglist}){
    $where.=" $arg{and_or} " if($where);
    $where.="$arg{region_ind} $arg{eq} $r->{region_id}";
  }
  return $where;
}

sub process_keywords{ # +
  my $keywords=shift;
  my @match_mas;
  
  foreach my $k (@{$keywords}){

    my $words=ecran_ind($Work::engine->param($k->{words}));
    #print  "words: $words\n";
    my @minus=();
    @minus=get_minus_words($Work::engine->param_mas($k->{words_minus})) if($k->{words_minus});

    unless(match_parens($words)){
      $words=~s/[\(\)\[\]]//g;
    }
    if($words){
      $words=ecran_ind($words);
      $words=~s/\sИ\s/ & /gs;
      $words=~s/( ИЛИ |,\s*)/ | /g;
      $words=~s/\[(.+?)\]/="$1"/g;

      my $cur_match;
      if($words=~m/^(\s*\-\S+\s*)+$/){ # все слова с минусом
        $words=~s/(^|\s)\-//g;
        $cur_match=qq{\@!$k->{field} ($words)};

      }
      else{
        $cur_match=qq{\@$k->{field} ($words)};
      }
      if(scalar(@minus)){
        foreach my $m (@minus){
          $m=~s/^-//;
          next if(length($m)<3);
          $cur_match.=' -'.$m;
        }
      }
      push @match_mas,$cur_match;

    }
    elsif(scalar(@minus)){ # для минус-слов должна быть какая-то хитрая конструкция
      # @!title hello world
      my $minus=join(' ',@minus);
      push @match_mas,qq{\@!$k->{field} $minus};
    }

  }
  return (scalar(@match_mas))?(join(' && ',map{"$_"} @match_mas)):'';
}
sub get_minus_words{ # +
  my $words_minus=shift;
  my $minus=[];
  foreach my $m ((split /\s+/,$words_minus)){
     next if(length($m)<3);
     $m=~s/[\(\)\[\]]//g;
     $m=~s/-\s+/ /g;
     $m=ecran_ind($m);
     push @{$minus},$m;
  }

  return @{$minus};
}
sub match_parens{ # +
   my $str = shift;  my $cnt; my $s; my $stop;
    eval q{
  return 1 if ($str=~m/^
      (?: (?{ $cnt = 0; $stop = 0; $s = ""; })
          (?> (?(?{ $stop })\G(?!))
            ([\(\[\{]) (?{ ++$cnt; $s .= $1; })
            |\) (?(?{ $cnt and (chop($s) eq "(") }) (?{ --$cnt; }) | (?{ ++$stop; })(?!))
            |\] (?(?{ $cnt and (chop($s) eq "[") }) (?{ --$cnt; }) | (?{ ++$stop; })(?!))
            |\} (?(?{ $cnt and (chop($s) eq "\{") }) (?{ --$cnt; }) | (?{ ++$stop; })(?!))
            |(?> [^()\[\]\{\}] )
          )*
      )
      (?(?{ $cnt }) (?!) )
   $/x);

  return 0;
  }
}


sub ecran_ind{
  my $str=shift;
  $str=~s/['\\\/]/ /gs;
  $str=~s/@/\\@/gs;
  $str=~s/([\/\+\."'\(\)\+\*\=\[\]\!])/\\$1/gs;
  $str=~s/^\s+$//;
  return $str;
}

return 1;
