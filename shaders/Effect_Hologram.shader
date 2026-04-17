Shader "PuddingKC/Effects/Hologram"
{
    Properties
    {
        [HDR] _TintColor ("Tint Color", Color) = (0.18, 0.92, 1.35, 1)
        [HDR] _EdgeColor ("Edge Color", Color) = (0.8, 1.0, 1.35, 1)
        _MainTex ("Main Tex", 2D) = "white" {}
        _Opacity ("Opacity", Range(0, 1)) = 0.55
        _FresnelPower ("Fresnel Power", Range(0.5, 8)) = 2.2
        _ScanlineDensity ("Scanline Density", Range(8, 220)) = 96
        _ScanSpeed ("Scan Speed", Range(0, 8)) = 1.2
        _ScanStrength ("Scan Strength", Range(0, 1)) = 0.18
        _Chromatic ("Chromatic Shift", Range(0, 0.02)) = 0.003
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Back

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _TintColor, _EdgeColor;
            float _Opacity, _FresnelPower, _ScanlineDensity, _ScanSpeed, _ScanStrength, _Chromatic;

            struct appdata
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 screenUV : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNormal = UnityObjectToWorldNormal(v.normal);

                o.vertex = UnityWorldToClipPos(float4(worldPos, 1.0));
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.screenUV = o.vertex.xy / max(o.vertex.w, 0.0001);
                o.worldNormal = normalize(worldNormal);
                o.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
                o.worldPos = worldPos;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float scanlines = sin(i.screenUV.y * _ScanlineDensity) * 0.5 + 0.5;
                float scanSweep = sin(i.worldPos.y * 8.0 - _Time.y * _ScanSpeed * 6.0) * 0.5 + 0.5;

                fixed4 texR = tex2D(_MainTex, i.uv + float2(_Chromatic, 0));
                fixed4 texG = tex2D(_MainTex, i.uv);
                fixed4 texB = tex2D(_MainTex, i.uv - float2(_Chromatic, 0));
                fixed4 texCol = fixed4(texR.r, texG.g, texB.b, texG.a);

                float fresnel = pow(1.0 - saturate(dot(i.worldNormal, i.viewDir)), _FresnelPower);

                fixed3 holo = texCol.rgb * _TintColor.rgb;
                holo *= 0.78 + scanlines * 0.18;
                holo += _TintColor.rgb * scanSweep * _ScanStrength;
                holo += _EdgeColor.rgb * fresnel * 1.2;
                holo = saturate(holo);

                float alpha = texCol.a * _Opacity;
                alpha += fresnel * 0.32;
                alpha += scanlines * 0.04;
                alpha += scanSweep * (_ScanStrength * 0.35);
                alpha = saturate(alpha);

                return fixed4(holo, alpha);
            }
            ENDCG
        }
    }

    Fallback Off
}
