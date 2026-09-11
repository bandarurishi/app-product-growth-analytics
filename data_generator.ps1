# data_generator.ps1
# Generates realistic synthetic event clickstream and user dimension data for Product Analytics

$OutputDir = Join-Path $PSScriptRoot "data"
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$UsersFile = Join-Path $OutputDir "dim_users.csv"
$EventsFile = Join-Path $OutputDir "fact_events.csv"

Write-Host "Generating dim_users.csv..." -ForegroundColor Cyan

$NumUsers = 10000
$Channels = @("Organic Search", "Paid Search (Google)", "Meta Ads (Instagram)", "Referral", "Influencer Campaign")
$Devices = @("Android", "iOS", "Web")
$Countries = @("United States", "India", "United Kingdom", "Canada", "Germany")
$ABGroups = @("Control_A", "Variant_B")

$Users = [System.Collections.Generic.List[PSObject]]::new()
$UserHeaders = "user_id,signup_date,signup_timestamp,channel,device_os,app_version,ab_test_group,country"
$UsersCsvLines = [System.Collections.Generic.List[string]]::new()
$UsersCsvLines.Add($UserHeaders)

$BaseStartDate = [DateTime]::Parse("2026-06-01 00:00:00")
$Random = [System.Random]::new(42)

for ($i = 1; $i -le $NumUsers; $i++) {
    $UserId = "usr_" + $i.ToString("D6")
    $DayOffset = $Random.Next(0, 90) # 90 days span (June, July, August 2026)
    $HourOffset = $Random.Next(0, 24)
    $MinOffset = $Random.Next(0, 60)
    $SecOffset = $Random.Next(0, 60)
    $SignupDateTime = $BaseStartDate.AddDays($DayOffset).AddHours($HourOffset).AddMinutes($MinOffset).AddSeconds($SecOffset)
    $SignupDate = $SignupDateTime.ToString("yyyy-MM-dd")
    $SignupTimestamp = $SignupDateTime.ToString("yyyy-MM-dd HH:mm:ss")
    
    # Weighted channel distribution
    $ChanRand = $Random.NextDouble()
    if ($ChanRand -lt 0.35) { $Channel = "Meta Ads (Instagram)" }
    elseif ($ChanRand -lt 0.60) { $Channel = "Paid Search (Google)" }
    elseif ($ChanRand -lt 0.80) { $Channel = "Organic Search" }
    elseif ($ChanRand -lt 0.92) { $Channel = "Referral" }
    else { $Channel = "Influencer Campaign" }

    # Device distribution (48% Android, 42% iOS, 10% Web)
    $DevRand = $Random.NextDouble()
    if ($DevRand -lt 0.48) { $Device = "Android" }
    elseif ($DevRand -lt 0.90) { $Device = "iOS" }
    else { $Device = "Web" }

    $Version = if ($Device -eq "Web") { "v3.1.0-web" } else { "v2.5." + $Random.Next(1, 4) }
    $Group = $ABGroups[$Random.Next(0, 2)] # 50-50 split
    $Country = $Countries[$Random.Next(0, $Countries.Count)]

    $UsersCsvLines.Add("$UserId,$SignupDate,$SignupTimestamp,$Channel,$Device,$Version,$Group,$Country")
    $Users.Add([PSCustomObject]@{
        UserId = $UserId
        SignupDateTime = $SignupDateTime
        Device = $Device
        Group = $Group
        Channel = $Channel
    })
}

[System.IO.File]::WriteAllLines($UsersFile, $UsersCsvLines)
Write-Host "Created $UsersFile with $NumUsers users." -ForegroundColor Green

Write-Host "Generating fact_events.csv with realistic funnel drop-offs and A/B test lift..." -ForegroundColor Cyan

$EventHeaders = "event_id,user_id,session_id,event_timestamp,event_name,session_duration_sec,feature_used"
$EventCsvLines = [System.Collections.Generic.List[string]]::new()
$EventCsvLines.Add($EventHeaders)

$GlobalEventId = 1

# Funnel milestones:
# Step 1: app_open (100%)
# Step 2: signup_initiated (88%)
# Step 3: signup_completed (Control A: 70%, Variant B: 82% lift)
# Step 4: kyc_initiated (iOS: 75%, Web: 68%, Android: 52% friction)
# Step 5: kyc_completed (Android: 62% of initiated due to camera doc upload failure, iOS: 88%)
# Step 6: first_core_action (Activation - 85% of KYC completed)

foreach ($u in $Users) {
    $SessionId = "sess_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 10)
    $CurrentTime = $u.SignupDateTime
    
    # Event 1: app_open
    $EventCsvLines.Add("evt_$GlobalEventId,$($u.UserId),$SessionId,$($CurrentTime.ToString('yyyy-MM-dd HH:mm:ss')),app_open,15,Splash_Screen")
    $GlobalEventId++

    # Event 2: signup_initiated (88% probability)
    if ($Random.NextDouble() -lt 0.88) {
        $CurrentTime = $CurrentTime.AddSeconds($Random.Next(10, 45))
        $EventCsvLines.Add("evt_$GlobalEventId,$($u.UserId),$SessionId,$($CurrentTime.ToString('yyyy-MM-dd HH:mm:ss')),signup_initiated,40,Auth_Modal")
        $GlobalEventId++

        # Event 3: signup_completed (Control A: 70%, Variant B: 82% lift)
        $CompleteProb = if ($u.Group -eq "Variant_B") { 0.82 } else { 0.70 }
        if ($Random.NextDouble() -lt $CompleteProb) {
            $CurrentTime = $CurrentTime.AddSeconds($Random.Next(30, 90))
            $EventCsvLines.Add("evt_$GlobalEventId,$($u.UserId),$SessionId,$($CurrentTime.ToString('yyyy-MM-dd HH:mm:ss')),signup_completed,75,Auth_Modal")
            $GlobalEventId++

            # Event 4: kyc_initiated (iOS: 75%, Web: 68%, Android: 52% friction)
            $KycInitProb = if ($u.Device -eq "iOS") { 0.75 } elseif ($u.Device -eq "Android") { 0.52 } else { 0.68 }
            if ($Random.NextDouble() -lt $KycInitProb) {
                $CurrentTime = $CurrentTime.AddSeconds($Random.Next(20, 60))
                $EventCsvLines.Add("evt_$GlobalEventId,$($u.UserId),$SessionId,$($CurrentTime.ToString('yyyy-MM-dd HH:mm:ss')),kyc_initiated,110,Identity_Verification")
                $GlobalEventId++

                # Event 5: kyc_completed (Android has 38% camera failure drop-off -> 0.62 conversion vs iOS 0.88)
                $KycCompProb = if ($u.Device -eq "Android") { 0.62 } else { 0.88 }
                if ($Random.NextDouble() -lt $KycCompProb) {
                    $CurrentTime = $CurrentTime.AddSeconds($Random.Next(60, 180))
                    $EventCsvLines.Add("evt_$GlobalEventId,$($u.UserId),$SessionId,$($CurrentTime.ToString('yyyy-MM-dd HH:mm:ss')),kyc_completed,240,Identity_Verification")
                    $GlobalEventId++

                    # Event 6: first_core_action (Activation: e.g. first transaction / portfolio creation)
                    if ($Random.NextDouble() -lt 0.85) {
                        $CurrentTime = $CurrentTime.AddSeconds($Random.Next(30, 120))
                        $EventCsvLines.Add("evt_$GlobalEventId,$($u.UserId),$SessionId,$($CurrentTime.ToString('yyyy-MM-dd HH:mm:ss')),first_core_action,320,Core_Dashboard")
                        $GlobalEventId++

                        # Subsequent Retention Events: D1, D3, D7, D14, D30 engagement
                        $RetentionSchedule = @(
                            @{ Day = 1; Prob = 0.55 },
                            @{ Day = 3; Prob = 0.42 },
                            @{ Day = 7; Prob = 0.34 },
                            @{ Day = 14; Prob = 0.26 },
                            @{ Day = 21; Prob = 0.22 },
                            @{ Day = 30; Prob = 0.18 }
                        )

                        foreach ($ret in $RetentionSchedule) {
                            $Bonus = if ($u.Group -eq "Variant_B") { 0.05 } else { 0.0 }
                            if ($Random.NextDouble() -lt ($ret.Prob + $Bonus)) {
                                $RetSession = "sess_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 10)
                                $RetTime = $u.SignupDateTime.AddDays($ret.Day).AddMinutes($Random.Next(10, 800))
                                
                                if ($RetTime -lt [DateTime]::Parse("2026-09-02 00:00:00")) {
                                    $EventCsvLines.Add("evt_$GlobalEventId,$($u.UserId),$RetSession,$($RetTime.ToString('yyyy-MM-dd HH:mm:ss')),app_open,18,Home_Feed")
                                    $GlobalEventId++
                                    $RetTime = $RetTime.AddSeconds($Random.Next(40, 200))
                                    $EventCsvLines.Add("evt_$GlobalEventId,$($u.UserId),$RetSession,$($RetTime.ToString('yyyy-MM-dd HH:mm:ss')),repeat_action,210,Feature_Usage")
                                    $GlobalEventId++
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

[System.IO.File]::WriteAllLines($EventsFile, $EventCsvLines)
Write-Host "Created $EventsFile with $GlobalEventId events." -ForegroundColor Green
Write-Host "Data generation completed successfully!" -ForegroundColor Cyan
