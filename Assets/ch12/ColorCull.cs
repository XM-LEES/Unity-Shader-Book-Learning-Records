using UnityEngine;
using System.Collections;

public class ColorCull : PostEffectsBase {

    public Shader ColorCullShader;
    private Material ColorCullMaterial;
    public Material material {
        get {
            ColorCullMaterial = CheckShaderAndCreateMaterial(ColorCullShader, ColorCullMaterial);
            return ColorCullMaterial;
        }
    }

    [Range(0, 1)]
    public int on = 1;

    [Range(0f, 359f)]
    public float hue = 0.0f;

	[Range(0.0f, 1.0f)]
	public float saturation = 1.0f;

	[Range(0.0f, 1.0f)]
	public float value = 1.0f;

	[Range(0.0f, 1.0f)]
	public float reserve = 1.0f;

    void OnRenderImage(RenderTexture src, RenderTexture dest) {
        if (material != null && on == 1) {
			material.SetFloat("_Hue", hue);
			material.SetFloat("_Saturation", saturation);
			material.SetFloat("_Value", value);
			material.SetFloat("_Reserve", reserve);

            Graphics.Blit(src, dest, material);
        } else {
            Graphics.Blit(src, dest);
        }
    }
}