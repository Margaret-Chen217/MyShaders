using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class ShaderInteractor : MonoBehaviour
{
    public Vector3 _Offset;
    void Start()
    {
        
        
    }

    // Update is called once per frame
    void Update()
    {
        //TODO: 设置shader中的变量
        Shader.SetGlobalVector("_PositionMoving", transform.position + _Offset);
        //Debug.Log(transform.position);
    }
}
