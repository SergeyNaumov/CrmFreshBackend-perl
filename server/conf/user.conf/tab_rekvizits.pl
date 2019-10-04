{
  description=>'Юр. адрес',
  name=>'ur_address',
  type=>'text',
  tab=>'rekvizits'
},
{
  description=>'Факт. адрес',
  name=>'address',
  type=>'text',
  tab=>'rekvizits'
},
{
  description=>'ИНН',
  name=>'inn',
  type=>'text',
  tab=>'rekvizits',
  before_code=>sub{
    my $e=shift;
    # для компаний с галкой "не экспортировать" ИНН не проверяем
    unless(
        (
          $form->{action}=~m{^(new|insert)$} && !($form->{manager}->{permissions}->{op_not_export} || $form->{manager}->{login} eq 'admin')
        )
        || $form->{old_values}->{not_export}
    ){
      $e->{regexp}='^(\d{10}|\d{12})$'
    }
    #pre($e);
    
  },
},
{
  description=>'КПП',
  name=>'kpp',
  type=>'text',
  tab=>'rekvizits',
  #regexp=>'^(\d{9})$'
},
{
  description=>'ОГРН',
  name=>'ogrn',
  type=>'text',
  tab=>'rekvizits',
  #regexp=>'^\d{13,15}$'
},
{
  description=>'р/с',
  name=>'rs',
  type=>'text',
  tab=>'rekvizits',
  #regexp=>'^\d{20}$'
},
{
  description=>'к/с',
  name=>'ks',
  type=>'text',
  tab=>'rekvizits',
  #regexp=>'^\d{20}$'
},
{
  description=>'БИК',
  name=>'bik',
  type=>'text',
  tab=>'rekvizits',
  #regexp=>'^(\d{9})$'
},
{
  description=>'Банк',
  name=>'bank',
  type=>'text',
  tab=>'rekvizits'
},
{
  description=>'Должность ответственного лица (именит.)',
  name=>'position_otv',
  type=>'text',
  tab=>'rekvizits'
},
{
  description=>'Должность ответственного лица (род.)',

  name=>'position_otv_rod',
  type=>'text',
  tab=>'rekvizits'
},
{
  description=>'ФИО ген. директора (именит.)',
  name=>'fio_dir',
  type=>'text',
  tab=>'rekvizits'
},
{
  description=>'ФИО ген. директора (родит.)',
  name=>'fio_dir_rod',
  type=>'text',
  tab=>'rekvizits'
},
{
  description=>'И.О. Фамилия директора',
  name=>'gen_dir_f_in',
  type=>'text',
  tab=>'rekvizits'
},
{ 
  name=>'btn2',
  tab=>'rekvizits',
  type=>'save_button',
}
