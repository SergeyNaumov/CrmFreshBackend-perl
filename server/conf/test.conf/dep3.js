function(value){
  if(value == 1){
    return [
      'dep1',{
        hide: false
      },
      'dep2',{
        hide: false
      },
      'dep3',{
        hide: false
      },
    ]
  }


  return ['url',
    {
      value:'/'+n_str,
      hide:true
    }
  ]
}