package connects;

sub get{
  [
    {
      name=>'crm_read',
      user=>'crm',
      host=>'localhost',
      dbname=>'crm'
    },
    {
      name=>'crm_write',
      user=>'crm',
      host=>'localhost',
      dbname=>'crm'
    },
  ];
};
return 1;
