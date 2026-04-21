param(
  [Parameter(Mandatory = $true)]
  [string]$ApiKey,
  [string]$Endpoint = 'https://fra.cloud.appwrite.io/v1',
  [string]$ProjectId = 'amttai',
  [string]$DatabaseId = 'amttai_db',
  [switch]$SeedRecipes = $true,
  [switch]$BackfillUserCodes = $true
)

$ErrorActionPreference = 'Stop'

$headers = @{
  'X-Appwrite-Project' = $ProjectId
  'X-Appwrite-Key' = $ApiKey
  'Content-Type' = 'application/json'
}

function Get-ErrorMessage {
  param([System.Management.Automation.ErrorRecord]$ErrorRecord)

  $message = $ErrorRecord.Exception.Message
  $response = $ErrorRecord.Exception.Response
  if ($null -eq $response) {
    return $message
  }

  try {
    $stream = $response.GetResponseStream()
    if ($null -ne $stream) {
      $reader = New-Object System.IO.StreamReader($stream)
      $body = $reader.ReadToEnd()
      if (-not [string]::IsNullOrWhiteSpace($body)) {
        return "$message :: $body"
      }
    }
  } catch {
    return $message
  }

  return $message
}

function Invoke-Appwrite {
  param(
    [string]$Method,
    [string]$Path,
    [object]$Body = $null,
    [switch]$Allow404
  )

  $uri = "$Endpoint$Path"
  try {
    if ($null -ne $Body) {
      $jsonBody = $Body | ConvertTo-Json -Depth 30 -Compress
      return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $jsonBody
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
  } catch {
    $response = $_.Exception.Response
    if ($Allow404 -and $null -ne $response) {
      try {
        if ([int]$response.StatusCode -eq 404) {
          return $null
        }
      } catch {}
    }

    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
      throw $_.ErrorDetails.Message
    }

    throw (Get-ErrorMessage -ErrorRecord $_)
  }
}

function Ensure-Database {
  param([string]$Id, [string]$Name)

  $db = Invoke-Appwrite -Method GET -Path "/databases/$Id" -Allow404
  if ($null -ne $db) {
    Write-Host "[OK] Database exists: $Id"
    return
  }

  Invoke-Appwrite -Method POST -Path '/databases' -Body @{
    databaseId = $Id
    name = $Name
    enabled = $true
  } | Out-Null
  Write-Host "[CREATE] Database created: $Id"
}

function Get-CollectionAttributes {
  param([string]$CollectionId)
  $attrs = Invoke-Appwrite -Method GET -Path "/databases/$DatabaseId/collections/$CollectionId/attributes"
  return @($attrs.attributes)
}

function Test-AttributeExists {
  param([string]$CollectionId, [string]$Key)
  $attrs = Get-CollectionAttributes -CollectionId $CollectionId
  return $attrs | Where-Object { $_.key -eq $Key } | Select-Object -First 1
}

function Ensure-Collection {
  param(
    [string]$Id,
    [string]$Name,
    [string[]]$Permissions,
    [bool]$DocumentSecurity = $false
  )

  $collection = Invoke-Appwrite -Method GET -Path "/databases/$DatabaseId/collections/$Id" -Allow404
  if ($null -ne $collection) {
    Write-Host "[OK] Collection exists: $Id"
    return
  }

  Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections" -Body @{
    collectionId = $Id
    name = $Name
    permissions = $Permissions
    documentSecurity = $DocumentSecurity
    enabled = $true
  } | Out-Null

  Write-Host "[CREATE] Collection created: $Id"
}

function Ensure-StringAttribute {
  param(
    [string]$CollectionId,
    [string]$Key,
    [int]$Size,
    [bool]$Required = $false,
    [bool]$Array = $false,
    [string]$Default = ''
  )

  if (Test-AttributeExists -CollectionId $CollectionId -Key $Key) {
    Write-Host "[OK] Attribute exists: $CollectionId.$Key"
    return
  }

  $body = @{
    key = $Key
    size = $Size
    required = $Required
    array = $Array
  }
  if ($Default -ne '') { $body.default = $Default }

  try {
    Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/string" -Body $body | Out-Null
    Write-Host "[CREATE] Attribute created: $CollectionId.$Key (string)"
  } catch {
    if ("$_" -like '*attribute_limit_exceeded*') {
      Write-Host "[WARN] Attribute skipped due collection limit: $CollectionId.$Key"
      return
    }
    throw
  }
}

function Ensure-EmailAttribute {
  param([string]$CollectionId, [string]$Key, [bool]$Required = $false)

  if (Test-AttributeExists -CollectionId $CollectionId -Key $Key) {
    Write-Host "[OK] Attribute exists: $CollectionId.$Key"
    return
  }

  Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/email" -Body @{
    key = $Key
    required = $Required
    array = $false
  } | Out-Null

  Write-Host "[CREATE] Attribute created: $CollectionId.$Key (email)"
}

function Ensure-IntegerAttribute {
  param(
    [string]$CollectionId,
    [string]$Key,
    [bool]$Required = $false,
    [int]$Min = 0,
    [int]$Max = 2147483647,
    [Nullable[int]]$Default = $null
  )

  if (Test-AttributeExists -CollectionId $CollectionId -Key $Key) {
    Write-Host "[OK] Attribute exists: $CollectionId.$Key"
    return
  }

  $body = @{
    key = $Key
    required = $Required
    min = $Min
    max = $Max
    array = $false
  }
  if ($null -ne $Default) { $body.default = $Default }

  Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/integer" -Body $body | Out-Null
  Write-Host "[CREATE] Attribute created: $CollectionId.$Key (integer)"
}

function Ensure-FloatAttribute {
  param(
    [string]$CollectionId,
    [string]$Key,
    [bool]$Required = $false,
    [double]$Min = 0,
    [double]$Max = 1000000,
    [Nullable[double]]$Default = $null
  )

  if (Test-AttributeExists -CollectionId $CollectionId -Key $Key) {
    Write-Host "[OK] Attribute exists: $CollectionId.$Key"
    return
  }

  $body = @{
    key = $Key
    required = $Required
    min = $Min
    max = $Max
    array = $false
  }
  if ($null -ne $Default) { $body.default = $Default }

  Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/float" -Body $body | Out-Null
  Write-Host "[CREATE] Attribute created: $CollectionId.$Key (float)"
}

function Ensure-BooleanAttribute {
  param(
    [string]$CollectionId,
    [string]$Key,
    [bool]$Required = $false,
    [Nullable[bool]]$Default = $null
  )

  if (Test-AttributeExists -CollectionId $CollectionId -Key $Key) {
    Write-Host "[OK] Attribute exists: $CollectionId.$Key"
    return
  }

  $body = @{
    key = $Key
    required = $Required
    array = $false
  }
  if ($null -ne $Default) { $body.default = $Default }

  Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/boolean" -Body $body | Out-Null
  Write-Host "[CREATE] Attribute created: $CollectionId.$Key (boolean)"
}

function Ensure-DatetimeAttribute {
  param(
    [string]$CollectionId,
    [string]$Key,
    [bool]$Required = $false
  )

  if (Test-AttributeExists -CollectionId $CollectionId -Key $Key) {
    Write-Host "[OK] Attribute exists: $CollectionId.$Key"
    return
  }

  Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/datetime" -Body @{
    key = $Key
    required = $Required
    array = $false
  } | Out-Null

  Write-Host "[CREATE] Attribute created: $CollectionId.$Key (datetime)"
}

function Ensure-EnumAttribute {
  param(
    [string]$CollectionId,
    [string]$Key,
    [string[]]$Elements,
    [bool]$Required = $false,
    [string]$Default = ''
  )

  if (Test-AttributeExists -CollectionId $CollectionId -Key $Key) {
    Write-Host "[OK] Attribute exists: $CollectionId.$Key"
    return
  }

  $body = @{
    key = $Key
    elements = $Elements
    required = $Required
    array = $false
  }
  if ($Default -ne '') { $body.default = $Default }

  Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/$CollectionId/attributes/enum" -Body $body | Out-Null
  Write-Host "[CREATE] Attribute created: $CollectionId.$Key (enum)"
}

function Get-Indexes {
  param([string]$CollectionId)
  $idx = Invoke-Appwrite -Method GET -Path "/databases/$DatabaseId/collections/$CollectionId/indexes"
  return @($idx.indexes)
}

function Ensure-Index {
  param(
    [string]$CollectionId,
    [string]$Key,
    [string]$Type,
    [string[]]$Attributes,
    [string[]]$Orders = @()
  )

  $existing = Get-Indexes -CollectionId $CollectionId | Where-Object { $_.key -eq $Key } | Select-Object -First 1
  if ($null -ne $existing) {
    Write-Host "[OK] Index exists: $CollectionId.$Key"
    return
  }

  $body = @{
    key = $Key
    type = $Type
    attributes = $Attributes
  }
  if ($Orders.Count -gt 0) { $body.orders = $Orders }

  try {
    Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/$CollectionId/indexes" -Body $body | Out-Null
    Write-Host "[CREATE] Index created: $CollectionId.$Key"
  } catch {
    Write-Host "[WARN] Index create deferred: $CollectionId.$Key :: $_"
  }
}

function Ensure-Bucket {
  param(
    [string]$BucketId,
    [string]$Name,
    [string[]]$Extensions,
    [Int64]$MaxSize = 5000000000
  )

  $bucket = Invoke-Appwrite -Method GET -Path "/storage/buckets/$BucketId" -Allow404
  if ($null -ne $bucket) {
    Write-Host "[OK] Bucket exists: $BucketId"
    return
  }

  Invoke-Appwrite -Method POST -Path '/storage/buckets' -Body @{
    bucketId = $BucketId
    name = $Name
    permissions = @('create("users")', 'read("users")')
    fileSecurity = $false
    enabled = $true
    maximumFileSize = $MaxSize
    allowedFileExtensions = $Extensions
    compression = 'none'
    encryption = $true
    antivirus = $true
  } | Out-Null

  Write-Host "[CREATE] Bucket created: $BucketId"
}

function New-JsonText {
  param([object]$Data)
  return ($Data | ConvertTo-Json -Depth 20 -Compress)
}

function New-RecipeSearchText {
  param(
    [string]$Title,
    [string]$Category,
    [string]$Description,
    [string[]]$Keywords = @()
  )

  $parts = @()
  foreach ($item in @($Title, $Category, $Description) + $Keywords) {
    $value = "$item".Trim()
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      $parts += $value.ToLowerInvariant()
    }
  }

  return ($parts | Select-Object -Unique) -join ' '
}

function New-SerializedUserCode {
  $now = [DateTime]::UtcNow
  $year = ($now.Year % 100).ToString('D2')
  $day = $now.DayOfYear.ToString('D3')

  $randomPart = -join ((1..6) | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 })
  $core = "$year$day$randomPart"

  $sum = 0
  for ($i = 0; $i -lt $core.Length; $i++) {
    $digit = [int]::Parse($core[$i].ToString())
    $weight = if ($i % 2 -eq 0) { 3 } else { 7 }
    $sum += ($digit * $weight)
  }

  $check = $sum % 10
  return "$core$check"
}

function Set-UserCodeWithRetry {
  param([string]$DocumentId)

  for ($attempt = 1; $attempt -le 15; $attempt++) {
    $candidate = New-SerializedUserCode
    try {
      Invoke-Appwrite -Method PATCH -Path "/databases/$DatabaseId/collections/users/documents/$DocumentId" -Body @{
        data = @{ user_code = $candidate }
      } | Out-Null
      return $candidate
    } catch {
      $msg = "$_"
      if ($msg -match 'already exists|duplicate|document_already_exists|index') {
        continue
      }
      throw
    }
  }

  throw "Unable to assign unique user_code for user document: $DocumentId"
}

function Backfill-UserCodes {
  $limit = 100
  $offset = 0

  do {
    $path = "/databases/$DatabaseId/collections/users/documents?limit=$limit&offset=$offset"

    $batch = Invoke-Appwrite -Method GET -Path $path
    $docs = @($batch.documents)

    foreach ($doc in $docs) {
      $docId = $doc.'$id'
      $currentCode = "$($doc.user_code)"
      if (-not [string]::IsNullOrWhiteSpace($currentCode)) {
        Write-Host "[OK] User code exists: $docId => $currentCode"
        continue
      }

      $newCode = Set-UserCodeWithRetry -DocumentId $docId
      Write-Host "[UPDATE] User code assigned: $docId => $newCode"
    }

    $offset += $docs.Count
  } while ($docs.Count -eq $limit)
}

function Backfill-RecipeSearchFields {
  $limit = 100
  $offset = 0

  do {
    $path = "/databases/$DatabaseId/collections/recipes/documents?limit=$limit&offset=$offset"

    $batch = Invoke-Appwrite -Method GET -Path $path
    $docs = @($batch.documents)

    foreach ($doc in $docs) {
      $existingSearch = "$($doc.search_text)".Trim()
      if (-not [string]::IsNullOrWhiteSpace($existingSearch)) {
        continue
      }

      $keywords = @()
      if ($doc.english_keywords -is [System.Array]) {
        $keywords = @($doc.english_keywords | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
      } elseif (-not [string]::IsNullOrWhiteSpace("$($doc.english_keywords)")) {
        $keywords = @("$($doc.english_keywords)".Split(',') | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
      }

      $searchText = New-RecipeSearchText -Title "$($doc.title)" -Category "$($doc.category)" -Description "$($doc.description)" -Keywords $keywords
      if ([string]::IsNullOrWhiteSpace($searchText)) {
        continue
      }

      Invoke-Appwrite -Method PATCH -Path "/databases/$DatabaseId/collections/recipes/documents/$($doc.'$id')" -Body @{
        data = @{ search_text = $searchText }
      } | Out-Null

      Write-Host "[UPDATE] Recipe search_text assigned: $($doc.'$id')"
    }

    $offset += $docs.Count
  } while ($docs.Count -eq $limit)
}

function Seed-RecipeDocuments {
  $hasIngredientsJson = [bool](Test-AttributeExists -CollectionId 'recipes' -Key 'ingredients_json')
  $hasStepsJson = [bool](Test-AttributeExists -CollectionId 'recipes' -Key 'steps_json')
  $hasNutritionJson = [bool](Test-AttributeExists -CollectionId 'recipes' -Key 'nutrition_json')
  $hasEnglishKeywords = [bool](Test-AttributeExists -CollectionId 'recipes' -Key 'english_keywords')
  $hasSearchText = [bool](Test-AttributeExists -CollectionId 'recipes' -Key 'search_text')

  $existing = Invoke-Appwrite -Method GET -Path "/databases/$DatabaseId/collections/recipes/documents"
  $existingTitles = @{}
  foreach ($doc in $existing.documents) {
    if ($null -ne $doc.title -and "$($doc.title)" -ne '') {
      $existingTitles["$($doc.title)"] = $true
    }
  }

  $recipes = @(
    @{
      title = 'Buuz'
      description = 'Traditional Mongolian steamed dumplings.'
      category = 'traditional'
      image_url = 'https://images.unsplash.com/photo-1496116218417-1a781b1c416c?w=1200'
      video_url = $null
      prep_time_minutes = 40
      cook_time_minutes = 20
      servings = 4
      difficulty = 'medium'
      is_premium = $false
      ingredients_json = New-JsonText @(
        @{ name = 'Beef'; amount = '500'; unit = 'g' },
        @{ name = 'Onion'; amount = '2'; unit = 'pcs' },
        @{ name = 'Flour'; amount = '400'; unit = 'g' }
      )
      steps_json = New-JsonText @(
        @{ order = 1; description = 'Prepare dough.' },
        @{ order = 2; description = 'Mix filling.' },
        @{ order = 3; description = 'Steam for 20 minutes.' }
      )
      nutrition_json = New-JsonText @{ calories = 280; protein = 18; carbs = 25; fat = 12 }
      average_rating = 4.8
      total_ratings = 156
      created_at = '2025-01-15T00:00:00.000Z'
      english_keywords = @('buuz', 'dumpling', 'steamed', 'mongolian')
    },
    @{
      title = 'Khuushuur'
      description = 'Deep fried Mongolian meat pastry.'
      category = 'traditional'
      image_url = 'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=1200'
      video_url = $null
      prep_time_minutes = 30
      cook_time_minutes = 15
      servings = 4
      difficulty = 'easy'
      is_premium = $false
      ingredients_json = New-JsonText @(
        @{ name = 'Mutton'; amount = '400'; unit = 'g' },
        @{ name = 'Onion'; amount = '2'; unit = 'pcs' },
        @{ name = 'Flour'; amount = '350'; unit = 'g' }
      )
      steps_json = New-JsonText @(
        @{ order = 1; description = 'Make dough and filling.' },
        @{ order = 2; description = 'Wrap and seal.' },
        @{ order = 3; description = 'Deep fry until golden.' }
      )
      nutrition_json = New-JsonText @{ calories = 350; protein = 15; carbs = 30; fat = 20 }
      average_rating = 4.6
      total_ratings = 203
      created_at = '2025-01-20T00:00:00.000Z'
      english_keywords = @('khuushuur', 'fried pastry', 'meat pie', 'mongolian')
    },
    @{
      title = 'Tsuivan'
      description = 'Stir-fried noodle dish with meat and vegetables.'
      category = 'main'
      image_url = 'https://images.unsplash.com/photo-1569058242253-92a9c755a0ec?w=1200'
      video_url = $null
      prep_time_minutes = 25
      cook_time_minutes = 20
      servings = 3
      difficulty = 'medium'
      is_premium = $false
      ingredients_json = New-JsonText @(
        @{ name = 'Beef'; amount = '300'; unit = 'g' },
        @{ name = 'Flour'; amount = '300'; unit = 'g' },
        @{ name = 'Vegetables'; amount = '200'; unit = 'g' }
      )
      steps_json = New-JsonText @(
        @{ order = 1; description = 'Prepare hand-cut noodles.' },
        @{ order = 2; description = 'Cook meat and vegetables.' },
        @{ order = 3; description = 'Add noodles and stir-fry.' }
      )
      nutrition_json = New-JsonText @{ calories = 310; protein = 20; carbs = 35; fat = 10 }
      average_rating = 4.5
      total_ratings = 98
      created_at = '2025-02-01T00:00:00.000Z'
      english_keywords = @('tsuivan', 'stir fry noodles', 'noodle', 'mongolian')
    },
    @{
      title = 'Guriltai Shul'
      description = 'Traditional soup with dough pieces and meat.'
      category = 'soup'
      image_url = 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=1200'
      video_url = $null
      prep_time_minutes = 15
      cook_time_minutes = 40
      servings = 4
      difficulty = 'easy'
      is_premium = $false
      ingredients_json = New-JsonText @(
        @{ name = 'Mutton'; amount = '400'; unit = 'g' },
        @{ name = 'Flour'; amount = '200'; unit = 'g' },
        @{ name = 'Potato'; amount = '2'; unit = 'pcs' }
      )
      steps_json = New-JsonText @(
        @{ order = 1; description = 'Boil meat.' },
        @{ order = 2; description = 'Prepare dough pieces.' },
        @{ order = 3; description = 'Cook together until done.' }
      )
      nutrition_json = New-JsonText @{ calories = 220; protein = 16; carbs = 28; fat = 6 }
      average_rating = 4.3
      total_ratings = 87
      created_at = '2025-02-05T00:00:00.000Z'
      english_keywords = @('guriltai shul', 'soup', 'noodle soup', 'mongolian')
    },
    @{
      title = 'Suutei Tsai'
      description = 'Classic Mongolian milk tea.'
      category = 'drink'
      image_url = 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=1200'
      video_url = $null
      prep_time_minutes = 5
      cook_time_minutes = 10
      servings = 4
      difficulty = 'easy'
      is_premium = $false
      ingredients_json = New-JsonText @(
        @{ name = 'Tea leaves'; amount = '2'; unit = 'tbsp' },
        @{ name = 'Milk'; amount = '500'; unit = 'ml' },
        @{ name = 'Water'; amount = '500'; unit = 'ml' }
      )
      steps_json = New-JsonText @(
        @{ order = 1; description = 'Boil water with tea.' },
        @{ order = 2; description = 'Add milk and simmer.' },
        @{ order = 3; description = 'Season lightly with salt.' }
      )
      nutrition_json = New-JsonText @{ calories = 80; protein = 4; carbs = 6; fat = 5 }
      average_rating = 4.7
      total_ratings = 312
      created_at = '2025-02-10T00:00:00.000Z'
      english_keywords = @('suutei tsai', 'milk tea', 'tea', 'mongolian')
    },
    @{
      title = 'Bantan'
      description = 'Quick warming soup for cold days.'
      category = 'soup'
      image_url = 'https://images.unsplash.com/photo-1476718406336-bb5a9690ee2a?w=1200'
      video_url = $null
      prep_time_minutes = 10
      cook_time_minutes = 20
      servings = 2
      difficulty = 'easy'
      is_premium = $false
      ingredients_json = New-JsonText @(
        @{ name = 'Mutton'; amount = '200'; unit = 'g' },
        @{ name = 'Flour'; amount = '100'; unit = 'g' },
        @{ name = 'Water'; amount = '800'; unit = 'ml' }
      )
      steps_json = New-JsonText @(
        @{ order = 1; description = 'Cook meat in water.' },
        @{ order = 2; description = 'Add flour bits.' },
        @{ order = 3; description = 'Simmer until thickened.' }
      )
      nutrition_json = New-JsonText @{ calories = 180; protein = 12; carbs = 22; fat = 5 }
      average_rating = 4.2
      total_ratings = 65
      created_at = '2025-02-15T00:00:00.000Z'
      english_keywords = @('bantan', 'soup', 'quick soup', 'mongolian')
    },
    @{
      title = 'Boodog'
      description = 'Traditional stone-cooked whole-meat dish.'
      category = 'traditional'
      image_url = 'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200'
      video_url = $null
      prep_time_minutes = 60
      cook_time_minutes = 120
      servings = 8
      difficulty = 'hard'
      is_premium = $true
      ingredients_json = New-JsonText @(
        @{ name = 'Whole lamb'; amount = '1'; unit = 'pc' },
        @{ name = 'Hot stones'; amount = '15'; unit = 'pcs' },
        @{ name = 'Onion'; amount = '3'; unit = 'pcs' }
      )
      steps_json = New-JsonText @(
        @{ order = 1; description = 'Prepare meat and hot stones.' },
        @{ order = 2; description = 'Fill and seal vessel.' },
        @{ order = 3; description = 'Cook slowly for around 2 hours.' }
      )
      nutrition_json = New-JsonText @{ calories = 450; protein = 35; carbs = 5; fat = 32 }
      average_rating = 4.9
      total_ratings = 45
      created_at = '2025-03-01T00:00:00.000Z'
      english_keywords = @('boodog', 'stone cooked', 'lamb', 'mongolian')
    },
    @{
      title = 'Khorhog'
      description = 'Premium Mongolian mutton cooked with hot stones.'
      category = 'traditional'
      image_url = 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200'
      video_url = $null
      prep_time_minutes = 30
      cook_time_minutes = 90
      servings = 6
      difficulty = 'hard'
      is_premium = $true
      ingredients_json = New-JsonText @(
        @{ name = 'Mutton'; amount = '2'; unit = 'kg' },
        @{ name = 'Potato'; amount = '4'; unit = 'pcs' },
        @{ name = 'Hot stones'; amount = '10'; unit = 'pcs' }
      )
      steps_json = New-JsonText @(
        @{ order = 1; description = 'Heat stones in fire.' },
        @{ order = 2; description = 'Layer meat and vegetables.' },
        @{ order = 3; description = 'Cook in sealed container.' }
      )
      nutrition_json = New-JsonText @{ calories = 400; protein = 30; carbs = 15; fat = 25 }
      average_rating = 4.9
      total_ratings = 67
      created_at = '2025-04-01T00:00:00.000Z'
      english_keywords = @('khorhog', 'stone pot', 'mutton', 'mongolian')
    }
  )

  foreach ($recipe in $recipes) {
    if ($existingTitles.ContainsKey($recipe.title)) {
      Write-Host "[OK] Recipe exists: $($recipe.title)"
      continue
    }

    $data = @{
      title = $recipe.title
      description = $recipe.description
      category = $recipe.category
      image_url = $recipe.image_url
      video_url = $recipe.video_url
      prep_time_minutes = $recipe.prep_time_minutes
      cook_time_minutes = $recipe.cook_time_minutes
      servings = $recipe.servings
      difficulty = $recipe.difficulty
      is_premium = $recipe.is_premium
      ingredients = $recipe.ingredients_json
      steps = $recipe.steps_json
      nutrition = $recipe.nutrition_json
      average_rating = $recipe.average_rating
      total_ratings = $recipe.total_ratings
      created_at = $recipe.created_at
    }

    $searchText = New-RecipeSearchText -Title $recipe.title -Category $recipe.category -Description $recipe.description -Keywords $recipe.english_keywords

    if ($hasIngredientsJson) { $data.ingredients_json = $recipe.ingredients_json }
    if ($hasStepsJson) { $data.steps_json = $recipe.steps_json }
    if ($hasNutritionJson) { $data.nutrition_json = $recipe.nutrition_json }
    if ($hasEnglishKeywords) { $data.english_keywords = $recipe.english_keywords }
    if ($hasSearchText) { $data.search_text = $searchText }

    foreach ($key in @($data.Keys)) {
      if ($null -eq $data[$key]) {
        $data.Remove($key)
      }
    }

    Invoke-Appwrite -Method POST -Path "/databases/$DatabaseId/collections/recipes/documents" -Body @{
      documentId = 'unique()'
      data = $data
    } | Out-Null

    Write-Host "[SEED] Recipe inserted: $($recipe.title)"
  }
}

function Check-FunctionPresence {
  $functions = Invoke-Appwrite -Method GET -Path '/functions'
  $existingIds = @($functions.functions | ForEach-Object { $_.'$id' })

  foreach ($requiredId in @('delete-account', 'broadcast-push')) {
    if ($existingIds -contains $requiredId) {
      Write-Host "[OK] Function exists: $requiredId"
    } else {
      Write-Host "[WARN] Function missing: $requiredId"
    }
  }
}

Write-Host '---- Appwrite Provisioning Started ----'
Write-Host "Endpoint: $Endpoint"
Write-Host "Project: $ProjectId"
Write-Host "Database: $DatabaseId"

Ensure-Database -Id $DatabaseId -Name 'Amttai Main Database'

$userPermissions = @('create("users")', 'read("users")', 'update("users")', 'delete("users")')
$recipePermissions = @('read("users")')

Ensure-Collection -Id 'recipes' -Name 'Recipes' -Permissions $recipePermissions -DocumentSecurity $false
Ensure-Collection -Id 'users' -Name 'Users' -Permissions $userPermissions -DocumentSecurity $false
Ensure-Collection -Id 'ratings' -Name 'Ratings' -Permissions $userPermissions -DocumentSecurity $false
Ensure-Collection -Id 'payments' -Name 'Payments' -Permissions $userPermissions -DocumentSecurity $false
Ensure-Collection -Id 'support_messages' -Name 'Support Messages' -Permissions $userPermissions -DocumentSecurity $false

# recipes attributes
Ensure-StringAttribute -CollectionId 'recipes' -Key 'title' -Size 255 -Required $true
Ensure-StringAttribute -CollectionId 'recipes' -Key 'description' -Size 10000 -Required $true
Ensure-StringAttribute -CollectionId 'recipes' -Key 'category' -Size 64 -Required $true
Ensure-StringAttribute -CollectionId 'recipes' -Key 'image_url' -Size 2048 -Required $false
Ensure-StringAttribute -CollectionId 'recipes' -Key 'video_url' -Size 2048 -Required $false
Ensure-IntegerAttribute -CollectionId 'recipes' -Key 'prep_time_minutes' -Required $true -Min 0 -Max 10000
Ensure-IntegerAttribute -CollectionId 'recipes' -Key 'cook_time_minutes' -Required $true -Min 0 -Max 10000
Ensure-IntegerAttribute -CollectionId 'recipes' -Key 'servings' -Required $true -Min 1 -Max 1000
Ensure-EnumAttribute -CollectionId 'recipes' -Key 'difficulty' -Elements @('easy', 'medium', 'hard') -Required $true -Default 'easy'
Ensure-BooleanAttribute -CollectionId 'recipes' -Key 'is_premium' -Required $true -Default $false
Ensure-StringAttribute -CollectionId 'recipes' -Key 'ingredients_json' -Size 65535 -Required $false
Ensure-StringAttribute -CollectionId 'recipes' -Key 'steps_json' -Size 65535 -Required $false
Ensure-StringAttribute -CollectionId 'recipes' -Key 'nutrition_json' -Size 65535 -Required $false
Ensure-StringAttribute -CollectionId 'recipes' -Key 'english_keywords' -Size 64 -Required $false -Array $true
Ensure-StringAttribute -CollectionId 'recipes' -Key 'search_text' -Size 10000 -Required $false
Ensure-FloatAttribute -CollectionId 'recipes' -Key 'average_rating' -Required $true -Min 0 -Max 5 -Default 0
Ensure-IntegerAttribute -CollectionId 'recipes' -Key 'total_ratings' -Required $true -Min 0 -Max 1000000 -Default 0
Ensure-DatetimeAttribute -CollectionId 'recipes' -Key 'created_at' -Required $true

Ensure-Index -CollectionId 'recipes' -Key 'idx_recipes_created_at' -Type 'key' -Attributes @('created_at') -Orders @('DESC')
Ensure-Index -CollectionId 'recipes' -Key 'idx_recipes_category' -Type 'key' -Attributes @('category') -Orders @('ASC')
Ensure-Index -CollectionId 'recipes' -Key 'idx_recipes_is_premium' -Type 'key' -Attributes @('is_premium') -Orders @('ASC')
Ensure-Index -CollectionId 'recipes' -Key 'idx_recipes_avg_rating' -Type 'key' -Attributes @('average_rating') -Orders @('DESC')
Ensure-Index -CollectionId 'recipes' -Key 'idx_recipes_title_fulltext' -Type 'fulltext' -Attributes @('title')
Ensure-Index -CollectionId 'recipes' -Key 'idx_recipes_search_text_fulltext' -Type 'fulltext' -Attributes @('search_text')
Ensure-Index -CollectionId 'recipes' -Key 'idx_recipes_cat_premium_created' -Type 'key' -Attributes @('category', 'is_premium', 'created_at') -Orders @('ASC', 'ASC', 'DESC')

# users attributes
Ensure-StringAttribute -CollectionId 'users' -Key 'name' -Size 255 -Required $true
Ensure-EmailAttribute -CollectionId 'users' -Key 'email' -Required $true
Ensure-StringAttribute -CollectionId 'users' -Key 'phone' -Size 32 -Required $false
Ensure-StringAttribute -CollectionId 'users' -Key 'photo_url' -Size 2048 -Required $false
Ensure-StringAttribute -CollectionId 'users' -Key 'user_code' -Size 12 -Required $false
Ensure-StringAttribute -CollectionId 'users' -Key 'push_tokens' -Size 512 -Required $false -Array $true
Ensure-BooleanAttribute -CollectionId 'users' -Key 'is_premium' -Required $true -Default $false
Ensure-DatetimeAttribute -CollectionId 'users' -Key 'premium_expires_at' -Required $false
Ensure-StringAttribute -CollectionId 'users' -Key 'favorite_recipe_ids' -Size 64 -Required $false -Array $true
Ensure-DatetimeAttribute -CollectionId 'users' -Key 'created_at' -Required $true

Ensure-Index -CollectionId 'users' -Key 'idx_users_email_unique' -Type 'unique' -Attributes @('email')
Ensure-Index -CollectionId 'users' -Key 'idx_users_user_code_unique' -Type 'unique' -Attributes @('user_code')
Ensure-Index -CollectionId 'users' -Key 'idx_users_is_premium' -Type 'key' -Attributes @('is_premium') -Orders @('ASC')

# ratings attributes
Ensure-StringAttribute -CollectionId 'ratings' -Key 'user_id' -Size 64 -Required $true
Ensure-StringAttribute -CollectionId 'ratings' -Key 'recipe_id' -Size 64 -Required $true
Ensure-IntegerAttribute -CollectionId 'ratings' -Key 'rating' -Required $true -Min 1 -Max 5
Ensure-DatetimeAttribute -CollectionId 'ratings' -Key 'created_at' -Required $true
Ensure-DatetimeAttribute -CollectionId 'ratings' -Key 'updated_at' -Required $true

Ensure-Index -CollectionId 'ratings' -Key 'idx_ratings_user_recipe_unique' -Type 'unique' -Attributes @('user_id', 'recipe_id')
Ensure-Index -CollectionId 'ratings' -Key 'idx_ratings_recipe' -Type 'key' -Attributes @('recipe_id') -Orders @('ASC')
Ensure-Index -CollectionId 'ratings' -Key 'idx_ratings_user' -Type 'key' -Attributes @('user_id') -Orders @('ASC')

# payments attributes
Ensure-StringAttribute -CollectionId 'payments' -Key 'user_id' -Size 64 -Required $true
Ensure-EnumAttribute -CollectionId 'payments' -Key 'plan' -Elements @('oneMonth', 'threeMonth', 'sixMonth', 'oneYear') -Required $true -Default 'oneMonth'
Ensure-IntegerAttribute -CollectionId 'payments' -Key 'amount' -Required $true -Min 0 -Max 100000000
Ensure-StringAttribute -CollectionId 'payments' -Key 'transaction_code' -Size 128 -Required $true
Ensure-StringAttribute -CollectionId 'payments' -Key 'transaction_id' -Size 128 -Required $false
Ensure-EnumAttribute -CollectionId 'payments' -Key 'status' -Elements @('pending', 'approved', 'rejected') -Required $true -Default 'pending'
Ensure-DatetimeAttribute -CollectionId 'payments' -Key 'created_at' -Required $true
Ensure-DatetimeAttribute -CollectionId 'payments' -Key 'verified_at' -Required $false

Ensure-Index -CollectionId 'payments' -Key 'idx_payments_user_created' -Type 'key' -Attributes @('user_id', 'created_at') -Orders @('ASC', 'DESC')
Ensure-Index -CollectionId 'payments' -Key 'idx_payments_tx_code' -Type 'key' -Attributes @('transaction_code') -Orders @('ASC')
Ensure-Index -CollectionId 'payments' -Key 'idx_payments_user_tx_created' -Type 'key' -Attributes @('user_id', 'transaction_code', 'created_at') -Orders @('ASC', 'ASC', 'DESC')

# support_messages attributes
Ensure-StringAttribute -CollectionId 'support_messages' -Key 'user_id' -Size 64 -Required $true
Ensure-StringAttribute -CollectionId 'support_messages' -Key 'message' -Size 5000 -Required $true
Ensure-BooleanAttribute -CollectionId 'support_messages' -Key 'is_from_admin' -Required $true -Default $false
Ensure-DatetimeAttribute -CollectionId 'support_messages' -Key 'created_at' -Required $true

Ensure-Index -CollectionId 'support_messages' -Key 'idx_support_user_created' -Type 'key' -Attributes @('user_id', 'created_at') -Orders @('ASC', 'ASC')
Ensure-Index -CollectionId 'support_messages' -Key 'idx_support_created' -Type 'key' -Attributes @('created_at') -Orders @('ASC')

# buckets
Ensure-Bucket -BucketId 'recipe_images' -Name 'Recipe Images' -Extensions @('jpg', 'png', 'webp', 'gif')
Ensure-Bucket -BucketId 'recipe_videos' -Name 'Instruction Videos' -Extensions @('mp4', 'mov', 'webm')
Ensure-Bucket -BucketId 'profile_photos' -Name 'Profile Photos' -Extensions @('jpg', 'png', 'jfif', 'gif', 'webp')
Ensure-Bucket -BucketId 'payment_screenshots' -Name 'Payment Screenshots' -Extensions @('jpg', 'png', 'jfif', 'webp')

if ($BackfillUserCodes) {
  if (Test-AttributeExists -CollectionId 'users' -Key 'user_code') {
    Backfill-UserCodes
  } else {
    Write-Host '[WARN] Skipping user code backfill: users.user_code attribute is not available yet.'
  }
}

if ($SeedRecipes) {
  Seed-RecipeDocuments
}

if (Test-AttributeExists -CollectionId 'recipes' -Key 'search_text') {
  Backfill-RecipeSearchFields
} else {
  Write-Host '[WARN] Skipping recipe search_text backfill: recipes.search_text attribute is not available yet.'
}

Check-FunctionPresence

Write-Host '---- Appwrite Provisioning Completed ----'